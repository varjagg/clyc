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

;;; Struct: restriction-link-data
;;; Conc-name: restr-link-data-
;;; Slots: (bindings hl-module)

(defstruct (restriction-link-data
            (:conc-name "RESTR-LINK-DATA-"))
  bindings
  hl-module)

(defconstant *dtp-restriction-link-data* 'restriction-link-data)

(defun restriction-link-data-print-function-trampoline (object stream)
  (default-struct-print-function object stream 0))

(defun restriction-link-data-p (object)
  (typep object 'restriction-link-data))

;;; Struct: restriction-listening-link-data
;;; Conc-name: restr-listen-link-data-
;;; Slots: (bindings hl-module listeners)

(defstruct (restriction-listening-link-data
            (:conc-name "RESTR-LISTEN-LINK-DATA-"))
  bindings
  hl-module
  listeners)

(defconstant *dtp-restriction-listening-link-data* 'restriction-listening-link-data)

;; restriction-listening-link-data-print-function-trampoline is not referenced
;; in any body; the struct uses default-struct-print-function via the trampoline
;; registered in setup.

(defun restriction-listening-link-data-p (object)
  (typep object 'restriction-listening-link-data))

(defun new-restriction-link (supported-problem supporting-mapped-problem
                             restriction-bindings
                             &optional listening-link? hl-module)
  "[Cyc] Return restriction-link-p;
RESTRICTION-BINDINGS binding-list-p; SUPPORTED-PROBLEM's vars -> restriction.
i.e. bindings to substitute into SUPPORTED-PROBLEM to restrict it."
  (declare (type problem-p supported-problem))
  (when supporting-mapped-problem
    (check-type supporting-mapped-problem mapped-problem-p))
  (let ((link (new-problem-link :restriction supported-problem)))
    (if listening-link?
        ;; Likely creates restriction-listening-link-data for the link
        (missing-larkc 35678)
        (new-restriction-link-data link))
    (when hl-module
      ;; Likely sets the hl-module on the link data
      (missing-larkc 35685))
    (set-restriction-link-bindings link restriction-bindings)
    (clear-restriction-link-listeners link)
    (connect-supporting-mapped-problem-with-dependent-link supporting-mapped-problem link)
    (problem-link-open-all link)
    (propagate-problem-link link)
    link))

(defun new-restriction-link-data (restriction-link)
  (let ((data (make-restriction-link-data)))
    (set-problem-link-data restriction-link data))
  restriction-link)

;; (defun new-restriction-listening-link-data (restriction-link) ...) -- active declareFunction, no body
;; (defun destroy-restriction-link (restriction-link) ...) -- active declareFunction, no body

(defun restriction-link-bindings (restriction-link)
  "[Cyc] The first elements of these bindings are in the space of RESTRICTION-LINK's
supported problem, and their second elements are in the space of
RESTRICTION-LINK's unique supporting problem."
  (declare (type restriction-link-p restriction-link))
  (let ((data (problem-link-data restriction-link)))
    (if (restriction-link-data-p data)
        (restr-link-data-bindings data)
        ;; Likely accesses bindings from restriction-listening-link-data
        (missing-larkc 35679))))

(defun restriction-link-hl-module (restriction-link)
  (declare (type restriction-link-p restriction-link))
  (let ((data (problem-link-data restriction-link)))
    (if (restriction-link-data-p data)
        (restr-link-data-hl-module data)
        ;; Likely accesses hl-module from restriction-listening-link-data
        (missing-larkc 35680))))

;; (defun restriction-link-listeners (restriction-link) ...) -- active declareFunction, no body

(defun set-restriction-link-bindings (restriction-link v-bindings)
  "[Cyc] RESTRICTION-BINDINGS; RESTRICTION-LINK's supported problem vars -> restriction"
  (declare (type restriction-link-p restriction-link))
  (declare (type binding-list-p v-bindings))
  (let ((data (problem-link-data restriction-link)))
    (if (restriction-link-data-p data)
        (setf (restr-link-data-bindings data) v-bindings)
        ;; Likely sets bindings on restriction-listening-link-data
        (missing-larkc 35668)))
  restriction-link)

;; (defun set-restriction-link-hl-module (restriction-link hl-module) ...) -- active declareFunction, no body

(defun clear-restriction-link-listeners (restriction-link)
  (declare (type restriction-link-p restriction-link))
  (let ((data (problem-link-data restriction-link)))
    (when (restriction-listening-link-data-p data)
      ;; Likely clears the listeners slot on restriction-listening-link-data
      (missing-larkc 35674)))
  restriction-link)

;; (defun add-restriction-link-listener (restriction-link listener) ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list38 = ((LISTENER RESTRICTION-LINK &KEY DONE) &BODY BODY) -- arglist
;; $sym42$DO_LIST -- iteration operator
;; $sym43$RESTRICTION_LINK_LISTENERS -- accessor for the list to iterate
;; Expansion confirmed in inference_worker_rewrite.java trigger_restriction_link_listeners
;; where restriction-link-listeners result is iterated via dolist/do-list pattern.
(defmacro do-restriction-link-listeners ((listener restriction-link &key done) &body body)
  `(do-list (,listener (restriction-link-listeners ,restriction-link) :done ,done)
     ,@body))

(defun restriction-listening-link-p (object)
  "[Cyc] Return booleanp;  Whether OBJECT is a listening restriction link."
  (and (problem-link-p object)
       (restriction-listening-link-data-p (problem-link-data object))))

;; (defun restriction-link-supporting-mapped-problem (restriction-link) ...) -- active declareFunction, no body
;; (defun restriction-link-supporting-variable-map (restriction-link) ...) -- active declareFunction, no body
;; (defun restriction-link-tactic (restriction-link) ...) -- active declareFunction, no body

(defun restriction-link-p (object)
  (and (problem-link-p object)
       (eq :restriction (problem-link-type object))))

(defun maybe-new-restriction-link (supported-problem supporting-mapped-problem
                                   restriction-bindings
                                   &optional listening-link? tactic)
  "[Cyc] Creates a new restriction link between SUPPORTING-PROBLEM and SUPPORTED-PROBLEM unless there already is one."
  (let ((set-contents-var (problem-dependent-links
                           (mapped-problem-problem supporting-mapped-problem))))
    (let* ((basis-object (do-set-contents-basis-object set-contents-var))
           (state (do-set-contents-initial-state basis-object set-contents-var)))
      (loop until (do-set-contents-done? basis-object state)
            do (let ((dependent-link (do-set-contents-next basis-object state)))
                 (when (do-set-contents-element-valid? state dependent-link)
                   (when (and (restriction-link-p dependent-link)
                              (eq supported-problem
                                  (problem-link-supported-problem dependent-link))
                              (bindings-equal? restriction-bindings
                                               (restriction-link-bindings dependent-link)))
                     (return-from maybe-new-restriction-link dependent-link))))
               (setf state (do-set-contents-update-state state)))))
  (let ((hl-module (if tactic
                       (tactic-hl-module tactic)
                       nil)))
    (new-restriction-link supported-problem supporting-mapped-problem
                          restriction-bindings listening-link? hl-module)))

(defun bubble-up-proof-to-restriction-link (restricted-proof restricted-variable-map
                                            restriction-link)
  "[Cyc] RESTRICTION-LINK connects a restricted-problem with an unrestricted-problem.
This function bubbles up RESTRICTED-PROOF to the unrestricted-problem via RESTRICTION-LINK.
RESTRICTED-VARIABLE-MAP; restricted problem's vars -> unrestricted-problem's vars"
  (let* ((restricted-bindings (proof-bindings restricted-proof))
         (restriction-bindings (restriction-link-bindings restriction-link))
         (unrestricted-bindings (proof-bindings-from-constituents
                                 restriction-bindings
                                 restricted-bindings
                                 restricted-variable-map)))
    (multiple-value-bind (unrestricted-proof new?)
        (new-restriction-proof restriction-link restricted-proof unrestricted-bindings)
      (trigger-restriction-link-listeners restriction-link restricted-proof)
      (if new?
          (bubble-up-proof unrestricted-proof)
          (possibly-note-proof-processed restricted-proof))))
  nil)

(defun new-restriction-proof (restriction-link restricted-proof unrestricted-bindings)
  "[Cyc] Return 0 proof-p
Return 1 whether the returned proof was newly created
RESTRICTION-BINDINGS; RESTRICTION-LINK's supported problem vars -> restriction"
  (let ((subproofs (list restricted-proof)))
    (propose-new-proof-with-bindings restriction-link
                                     (canonicalize-proof-bindings unrestricted-bindings)
                                     subproofs)))

;; (defun restriction-proof-p (proof) ...) -- active declareFunction, no body
;; (defun problem-has-restriction-link? (problem) ...) -- active declareFunction, no body
;; (defun restriction-proof-hl-module (proof) ...) -- active declareFunction, no body

(defparameter *simplification-tactics-execute-early-and-pass-down-transformation-motivation?* t
  "[Cyc] When T, simplification tactics are executed early (before backchain required transformation tactics) and pass down T motivation.")

(defun simplification-tactic-p (tactic)
  (and (tactic-p tactic)
       (simplification-module-p (tactic-hl-module tactic))))

(defun simplification-link-p (object)
  (and (restriction-link-p object)
       (simplification-module-p (restriction-link-hl-module object))))

(defun problem-is-a-simplification? (problem)
  (problem-has-dependent-link-of-type? problem :simplification))

(defun problem-has-a-simplification? (problem)
  (problem-has-argument-link-of-type? problem :simplification))

;; (defun problem-first-simplified-supporting-problem (problem) ...) -- active declareFunction, no body
