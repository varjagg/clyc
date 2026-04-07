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


;;; Variables

(defparameter *problem-link-datastructure-stores-proofs?* nil
  "[Cyc] If T, when a proof is created for a link and subproofs, the proof is also
added to the proofs slot of that link and used when finding link-proofs")


;;; problem-link defstruct

(defstruct (problem-link
            (:conc-name "prob-link-")
            (:predicate problem-link-p))
  suid
  type
  supported-object
  supporting-mapped-problems
  open-flags
  data
  proofs)

;; Reconstructed from format strings: $str32="<Invalid LINK ~s>",
;; $str33="<~a LINK ~a.~a supporting ", $str35="~a>", $str36="~a.~a>"
(defmethod print-object ((link problem-link) stream)
  (if (problem-link-invalid-p link)
      (format stream "<Invalid LINK ~s>" (prob-link-suid link))
      (let ((store (problem-link-store link)))
        (format stream "<~a LINK ~a.~a supporting "
                (prob-link-type link)
                (problem-store-suid store)
                (prob-link-suid link))
        (if (eq :answer (prob-link-type link))
            (format stream "~a>" (prob-link-supported-object link))
            (let ((supported-problem (prob-link-supported-object link)))
              (format stream "~a.~a>"
                      (problem-store-suid (problem-store supported-problem))
                      (problem-suid supported-problem)))))))

(defun sxhash-problem-link-method (object)
  (prob-link-suid object))


;;; problem-link functions

(defun valid-problem-link-p (object)
  (and (problem-link-p object)
       (not (problem-link-invalid-p object))))

(defun problem-link-invalid-p (problem-link)
  (eq :free (problem-link-type problem-link)))

;; (defun print-problem-link (object stream depth) ...) -- active declareFunction, no body

(defun new-problem-link (type supported-problem)
  "[Cyc] Creates a new link under SUPPORTED-PROBLEM"
  (declare (type (satisfies problem-link-type-p) type)
           (type (satisfies problem-p) supported-problem))
  (must (not (eq :answer type))
        "Can't call new-problem-link for an :answer link, call new-answer-link instead")
  (let ((link (new-problem-link-int supported-problem type)))
    (add-problem-argument-link supported-problem link)
    link))

(defun new-problem-link-int (supported-object type)
  (let ((link (make-problem-link)))
    (setf (prob-link-type link) type)
    (setf (prob-link-supported-object link) supported-object)
    (let* ((store (problem-link-store link))
           (suid (problem-store-new-link-id store)))
      (increment-problem-link-type-historical-counts type)
      (setf (prob-link-suid link) suid)
      (setf (prob-link-supporting-mapped-problems link) nil)
      (setf (prob-link-open-flags link) 0)
      (add-problem-store-link store link))
    link))

(defun destroy-problem-link (link)
  (when (valid-problem-link-p link)
    (let ((type (problem-link-type link))
          (store (problem-link-store link)))
      (note-problem-link-invalid link)
      (case type
        (:answer
         (let ((inference (problem-link-supported-object link)))
           (when (valid-inference-p inference)
             (destroy-inference inference))))
        (:removal
         (missing-larkc 36224))
        (:transformation
         (missing-larkc 36429))
        (:residual-transformation
         (missing-larkc 35053))
        (:join-ordered
         (missing-larkc 36361))
        (:join
         (missing-larkc 36480))
        (:split
         (missing-larkc 36477))
        (:union
         (missing-larkc 33006))
        (:restriction
         (missing-larkc 35676)))
      (when (not (eq :answer type))
        ;; Likely collects all proofs for the link and destroys them
        (let ((doomed-proofs (missing-larkc 35660)))
          (dolist (proof doomed-proofs)
            (when (valid-proof-p proof)
              (missing-larkc 35402)))))
      (do-problem-link-supporting-mapped-problems
          (supporting-mapped-problem link)
        (let ((supporting-problem (mapped-problem-problem supporting-mapped-problem)))
          (when (valid-problem-p supporting-problem)
            (remove-problem-dependent-link supporting-problem link))))
      (when (not (eq :answer type))
        (let ((supported-problem (problem-link-supported-problem link)))
          (when (valid-problem-p supported-problem)
            ;; Likely removes this link from the problem's argument links
            (missing-larkc 35388))))
      (remove-problem-store-link store link))
    (destroy-problem-link-int link)))

(defun destroy-problem-store-link (link)
  (when (valid-problem-link-p link)
    (note-problem-link-invalid link)
    (destroy-problem-link-int link)))

(defun destroy-problem-link-int (link)
  (setf (prob-link-data link) :free)
  (setf (prob-link-open-flags link) :free)
  (do-problem-link-supporting-mapped-problems (mapped-problem link)
    (destroy-problem-link-mapped-problem mapped-problem))
  (setf (prob-link-supporting-mapped-problems link) :free)
  (setf (prob-link-supported-object link) :free)
  nil)

(defun note-problem-link-invalid (link)
  (setf (prob-link-type link) :free)
  link)

(defun problem-link-suid (link)
  (declare (type problem-link link))
  (prob-link-suid link))

(defun problem-link-type (link)
  (declare (type problem-link link))
  (prob-link-type link))

(defun problem-link-supported-object (link)
  (declare (type problem-link link))
  (prob-link-supported-object link))

(defun problem-link-supporting-mapped-problems (link)
  (declare (type problem-link link))
  (prob-link-supporting-mapped-problems link))

(defun problem-link-open-flags (link)
  (declare (type problem-link link))
  (prob-link-open-flags link))

(defun problem-link-data (link)
  (declare (type problem-link link))
  (prob-link-data link))

(defun set-problem-link-open-flags (link flags)
  (declare (type problem-link link)
           (type integer flags))
  (setf (prob-link-open-flags link) flags)
  link)

(defun set-problem-link-data (link data)
  (declare (type problem-link link))
  (setf (prob-link-data link) data)
  link)

;; (defun add-problem-link-proof (link proof) ...) -- active declareFunction, no body
;; (defun remove-problem-link-proof (link proof) ...) -- active declareFunction, no body
;; (defun problem-link-supporting-problems (link) ...) -- active declareFunction, no body

(defun problem-link-store (link)
  (if (answer-link-p link)
      (inference-problem-store (problem-link-supported-inference link))
      (problem-store (problem-link-supported-problem link))))

(defun problem-link-has-type? (link type)
  (case type
    (:content (content-link-p link))
    (:structural
     ;; Likely checks whether the link is a structural link type
     (missing-larkc 35352))
    (:disjunctive (disjunctive-link-p link))
    (:conjunctive (conjunctive-link-p link))
    (:connected-conjunction (connected-conjunction-link-p link))
    (:logical (logical-link-p link))
    (:split/restriction
     (or (split-link-p link)
         (restriction-link-p link)))
    (:simplification (simplification-link-p link))
    (:removal-conjunctive (conjunctive-removal-link-p link))
    (otherwise (eq type (problem-link-type link)))))

(defun problem-link-supported-inference (link)
  (when (answer-link-p link)
    (problem-link-supported-object link)))

(defun problem-link-supported-problem (link)
  (when (not (answer-link-p link))
    (problem-link-supported-object link)))

(defun problem-link-with-supporting-problem-p (object)
  "[Cyc] @return boolean; t iff OBJECT is a problem-link with at least one argument
(child) link."
  (and (problem-link-p object)
       (not (null (problem-link-supporting-mapped-problems object)))))

;; (defun problem-link-with-single-supporting-problem-p (link) ...) -- active declareFunction, no body

(defun problem-link-number-of-supporting-problems (link)
  (problem-link-supporting-mapped-problem-count link))

(defun problem-link-supporting-mapped-problem-count (link)
  (length (problem-link-supporting-mapped-problems link)))

(defun problem-link-first-supporting-mapped-problem (link)
  (first (problem-link-supporting-mapped-problems link)))

(defun problem-link-sole-supporting-mapped-problem (link)
  (declare (type (satisfies problem-link-with-single-supporting-problem-p) link))
  (problem-link-first-supporting-mapped-problem link))

;; (defun problem-link-sole-supporting-variable-map (link) ...) -- active declareFunction, no body
;; (defun problem-link-first-supporting-problem (link) ...) -- active declareFunction, no body

(defun problem-link-sole-supporting-problem (link)
  "[Cyc] @param LINK problem-link-p;
@return problem-p; The sole supporting problem of LINK."
  (mapped-problem-problem (problem-link-sole-supporting-mapped-problem link)))

(defun problem-link-find-supporting-mapped-problem-by-index (link index)
  (nth index (problem-link-supporting-mapped-problems link)))

(defun problem-link-open? (link)
  (not (zerop (problem-link-open-flags link))))

(defun problem-link-closed? (link)
  (not (problem-link-open? link)))

(defun problem-link-index-open? (link index)
  (let ((flags (problem-link-open-flags link)))
    (get-bit flags index)))

(defun problem-link-supporting-mapped-problem-open? (link supporting-mapped-problem)
  (let ((index (position supporting-mapped-problem
                         (problem-link-supporting-mapped-problems link)
                         :test #'mapped-problem-equal)))
    (problem-link-index-open? link index)))

(defun problem-link-sole-supporting-mapped-problem-open? (link)
  (declare (type (satisfies problem-link-with-single-supporting-problem-p) link))
  (problem-link-index-open? link 0))

;; (defun supporting-mapped-problem-open-wrt-link? (supporting-mapped-problem link) ...) -- active declareFunction, no body
;; (defun supporting-problem-open-wrt-link? (supporting-problem link) ...) -- active declareFunction, no body
;; (defun problem-link-completely-open? (link) ...) -- active declareFunction, no body
;; (defun problem-link-has-some-proof? (link &optional strategy) ...) -- active declareFunction, no body
;; (defun problem-link-good? (link) ...) -- active declareFunction, no body
;; (defun problem-link-proofs (link) ...) -- active declareFunction, no body
;; (defun problem-link-all-proofs-computed (link) ...) -- active declareFunction, no body
;; (defun problem-link-all-proofs (link) ...) -- active declareFunction, no body
;; (defun problem-link-proof-count (link) ...) -- active declareFunction, no body
;; (defun problem-link-destructible? (link) ...) -- active declareFunction, no body
;; (defun problem-link-destructibility-status (link) ...) -- active declareFunction, no body

(defun add-problem-link-supporting-mapped-problem (link supporting-mapped-problem)
  "[Cyc] Adds SUPPORTING-PROBLEM to the list of problems below LINK"
  (declare (type problem-link link)
           (type mapped-problem supporting-mapped-problem))
  (setf (prob-link-supporting-mapped-problems link)
        (cons supporting-mapped-problem
              (prob-link-supporting-mapped-problems link)))
  link)

(defun problem-link-open-all (link)
  (let ((supporting-mapped-problem-count (problem-link-supporting-mapped-problem-count link))
        (flags 0))
    (dotimes (index supporting-mapped-problem-count)
      (setf flags (set-bit flags index t)))
    (set-problem-link-open-flags link flags))
  nil)

(defun problem-link-open-index (link index)
  (let ((flags (problem-link-open-flags link)))
    (setf flags (set-bit flags index t))
    (set-problem-link-open-flags link flags))
  nil)

(defun problem-link-open-supporting-mapped-problem (link supporting-mapped-problem)
  (let ((index (position supporting-mapped-problem
                         (problem-link-supporting-mapped-problems link)
                         :test #'mapped-problem-equal)))
    (when index
      (problem-link-open-index link index))))

(defun problem-link-open-sole-supporting-mapped-problem (link)
  (declare (type (satisfies problem-link-with-single-supporting-problem-p) link))
  (problem-link-open-index link 0))

(defun problem-link-close-index (link index)
  (let ((flags (problem-link-open-flags link)))
    (setf flags (set-bit flags index nil))
    (set-problem-link-open-flags link flags))
  nil)

(defun problem-link-close-all (link)
  (set-problem-link-open-flags link 0)
  link)

;; (defun problem-link-close-supporting-mapped-problem (link supporting-mapped-problem) ...) -- active declareFunction, no body

(defun problem-link-close-sole-supporting-mapped-problem (link)
  (declare (type (satisfies problem-link-with-single-supporting-problem-p) link))
  (problem-link-close-index link 0))

(defun connect-supporting-mapped-problem-with-dependent-link (supporting-mapped-problem link)
  "[Cyc] Adds a 'down' edge from LINK (above) to PROBLEM (below)"
  (declare (type mapped-problem supporting-mapped-problem)
           (type problem-link link))
  (add-problem-link-supporting-mapped-problem link supporting-mapped-problem)
  (add-problem-dependent-link (mapped-problem-problem supporting-mapped-problem) link)
  nil)

(defun problem-link-to-goal-p (link)
  "[Cyc] @return boolean; t iff LINK is a link to goal. The only links (except for
links in the middle of being created) which have no
supporting-mapped-problems are links to goal."
  (null (problem-link-supporting-mapped-problems link)))

;; (defun find-problem-link-of-type-between (type supported-problem supporting-problem) ...) -- active declareFunction, no body
;; (defun link-of-type-between? (link supported-problem supporting-problem) ...) -- active declareFunction, no body
;; (defun find-closed-supporting-problem-by-query (link query) ...) -- active declareFunction, no body
;; (defun find-supporting-mapped-problem-by-query-and-variable-map (link query variable-map) ...) -- active declareFunction, no body
;; (defun problem-link-supporting-mapped-problem-that-isnt (link mapped-problem) ...) -- active declareFunction, no body


;;; mapped-problem defstruct

(defstruct (mapped-problem
            (:conc-name "mapped-prob-")
            (:predicate mapped-problem-p))
  problem
  variable-map)

;; Reconstructed from format strings: $str81="<MAPPED PROBLEM:~a ~a>", $str82="#<"
(defmethod print-object ((mp mapped-problem) stream)
  (format stream "#<MAPPED PROBLEM:~a ~a>"
          (mapped-prob-problem mp)
          (mapped-prob-variable-map mp)))

(defun sxhash-mapped-problem-method (object)
  (logxor (sxhash (mapped-prob-problem object))
          (sxhash (mapped-prob-variable-map object))))


;;; mapped-problem functions

(defun valid-mapped-problem-p (object)
  (and (mapped-problem-p object)
       (not (eq :free (mapped-problem-variable-map object)))
       (valid-problem-p (mapped-problem-problem object))))

(defun mapped-problem-equal (mapped-problem1 mapped-problem2)
  (or (eq mapped-problem1 mapped-problem2)
      (let ((problem1 (mapped-problem-problem mapped-problem1))
            (problem2 (mapped-problem-problem mapped-problem2)))
        (when (eq problem1 problem2)
          (let ((variable-map1 (mapped-problem-variable-map mapped-problem1))
                (variable-map2 (mapped-problem-variable-map mapped-problem2)))
            (equal variable-map1 variable-map2))))))

;; (defun print-mapped-problem (object stream depth) ...) -- active declareFunction, no body
;; (defun closed-mapped-problem-p (object) ...) -- active declareFunction, no body

(defun new-mapped-problem (problem variable-map)
  (declare (type (satisfies problem-p) problem)
           (type (satisfies variable-map-p) variable-map))
  (let ((mp (make-mapped-problem)))
    (setf (mapped-prob-problem mp) problem)
    (setf (mapped-prob-variable-map mp) variable-map)
    mp))

;; (defun new-closed-mapped-problem (problem) ...) -- active declareFunction, no body

(defun destroy-problem-link-mapped-problem (mapped-problem)
  (when (valid-mapped-problem-p mapped-problem)
    (note-mapped-problem-invalid mapped-problem)
    (destroy-mapped-problem-int mapped-problem)))

(defun destroy-mapped-problem-int (mapped-problem)
  (setf (mapped-prob-problem mapped-problem) :free)
  nil)

(defun note-mapped-problem-invalid (mapped-problem)
  (setf (mapped-prob-variable-map mapped-problem) :free)
  mapped-problem)

(defun mapped-problem-problem (mapped-problem)
  (declare (type mapped-problem mapped-problem))
  (mapped-prob-problem mapped-problem))

(defun mapped-problem-variable-map (mapped-problem)
  "[Cyc] Variable maps go UP, i.e. (<supporting problem's vars> -> <supported
problem's vars>)"
  (declare (type mapped-problem mapped-problem))
  (mapped-prob-variable-map mapped-problem))

;; (defun supporting-mapped-problem-index (link supporting-mapped-problem) ...) -- active declareFunction, no body

(defun find-supporting-mapped-problem-by-index (link index)
  (let ((candidate-index 0))
    (do-problem-link-supporting-mapped-problems (supporting-mapped-problem link)
      (when (= index candidate-index)
        (return-from find-supporting-mapped-problem-by-index supporting-mapped-problem))
      (incf candidate-index)))
  nil)

;; (defun mapped-problem-query-as-subquery (mapped-problem) ...) -- active declareFunction, no body
;; (defun mapped-problem-equals-spec? (mapped-problem problem variable-map) ...) -- active declareFunction, no body


;;; Macros

;; Reconstructed from: $list88=((supporting-mapped-problem-var link problem &key open? done) &body body),
;; $sym93$PROBLEM_VAR (gensym), $sym94$CLET, $sym95$DO_PROBLEM_LINK_SUPPORTING_MAPPED_PROBLEMS,
;; $sym96$PWHEN, $sym97$MAPPED_PROBLEM_PROBLEM
(defmacro do-problem-link-supporting-mapped-problem-interpretations
    ((supporting-mapped-problem-var link problem &key open? done) &body body)
  (with-temp-vars (problem-var)
    `(let ((,problem-var ,problem))
       (do-problem-link-supporting-mapped-problems
           (,supporting-mapped-problem-var ,link :open? ,open? :done ,done)
         (when (eq (mapped-problem-problem ,supporting-mapped-problem-var)
                    ,problem-var)
           ,@body)))))

;; Reconstructed from: $list98=((variable-map-var link problem &key open? done) &body body),
;; $sym99$SUPPORTING_MAPPED_PROBLEM (gensym),
;; $sym100$DO_PROBLEM_LINK_SUPPORTING_MAPPED_PROBLEM_INTERPRETATIONS,
;; $sym101$MAPPED_PROBLEM_VARIABLE_MAP
(defmacro do-problem-link-supporting-variable-map-interpretations
    ((variable-map-var link problem &key open? done) &body body)
  (with-temp-vars (supporting-mapped-problem)
    `(do-problem-link-supporting-mapped-problem-interpretations
         (,supporting-mapped-problem ,link ,problem :open? ,open? :done ,done)
       (let ((,variable-map-var (mapped-problem-variable-map ,supporting-mapped-problem)))
         ,@body))))

;; (defun link-has-some-sibling-link? (link) ...) -- active declareFunction, no body


;;; Toplevel forms

(toplevel
  (define-obsolete-register 'problem-link-number-of-supporting-problems
                            '(problem-link-supporting-mapped-problem-count)))
