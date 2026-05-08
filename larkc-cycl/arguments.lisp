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

;; An abstraction over beliefs (asserted-arguments?) & deductions

;; Reconstructed from Internal Constants: $list0 (parameters), $str1$ "mapping Cyc arguments",
;; $sym2$ DO-ASSERTIONS, $sym3$ CDOLIST, $sym4$ ASSERTION-ARGUMENTS.
;; MESSAGE is passed positionally as do-assertions's progress-message arg per its signature
;; ((var &optional progress-message &key done) &body body) registered in assertion-handles.
(defmacro do-arguments ((assertion argument &optional (message "mapping Cyc arguments"))
                        &body body)
  `(do-assertions (,assertion ,message)
     (cdolist (,argument (assertion-arguments ,assertion))
       ,@body)))

;; Reconstructed from Internal Constants: $list5, $str6$ "mapping Cyc belief arguments",
;; $sym7$ DO-ARGUMENTS, $sym8$ PWHEN, $sym9$ BELIEF-P.
(defmacro do-beliefs ((assertion argument &optional (message "mapping Cyc belief arguments"))
                      &body body)
  `(do-arguments (,assertion ,argument ,message)
     (pwhen (belief-p ,argument)
       ,@body)))

;; Reconstructed from Internal Constants: $list10, $str11$ "mapping Cyc asserted arguments",
;; $sym7$ DO-ARGUMENTS, $sym8$ PWHEN, $sym12$ ASSERTED-ARGUMENT-P.
(defmacro do-asserted-arguments ((assertion argument
                                            &optional (message "mapping Cyc asserted arguments"))
                                 &body body)
  `(do-arguments (,assertion ,argument ,message)
     (pwhen (asserted-argument-p ,argument)
       ,@body)))

;; (defun argument-p (object) ...) -- active declaration, no body, Cyc API

(defun valid-argument (argument &optional robust)
  "[Cyc] Return T if ARGUMENT is a valid argument. ROBUST requests more thorough checking."
  (or (belief-p argument)
      (and (deduction-p argument)
           (valid-deduction argument robust))))

(defun* argument-spec-type (argument-spec) (:inline t)
  "[Cyc] Returns the type of the argument specified by ARGUMENT-SPEC."
  (car argument-spec))

;; (defun argument-spec-p (object) ...) -- active declaration, no body
;; (defun argument-to-argument-spec (argument) ...) -- active declaration, no body
;; (defun argument-type-p (object) ...) -- active declaration, no body

(deflexical *argument-types* (list :argument
                                   :belief
                                   :asserted-argument
                                   :deduction))

(deflexical *argument-type-hierarchy* '((:argument ())
                                        (:belief (:argument))
                                        (:asserted-argument (:belief))
                                        (:deduction (:argument)))
  "[Cyc] A list of pairs of the form (ARGUMENT-TYPE list-of-proper-genls).
Hardcodes the type hierarchy:
                ARGUMENT
               /        \ 
           BELIEF      DEDUCTION
            /
  ASSERTED-ARGUMENT")

(defun* argument-type-hierarchy () (:inline t)
  "[Cyc] A list of pairs of the form (ARGUMENT-TYPE list-of-proper-genls)."
  *argument-type-hierarchy*)

(defun argument-type-proper-genls (argument-type)
  "[Cyc] Returns the proper genls of ARGUMENT-TYPE in the hard-coded hierarchy."
  (when-let ((pair (assoc argument-type (argument-type-hierarchy))))
    (let* ((immediate-proper-genls (copy-list (second pair)))
           (recursive-proper-genls (mapcan #'argument-type-proper-genls immediate-proper-genls)))
      (append immediate-proper-genls recursive-proper-genls))))

(defun* argument-type-genls (argument-type) (:inline t)
  "[Cyc] Returns the genls of ARGUMENT-TYPE in the hard-coded hierarchy."
  (cons argument-type (argument-type-proper-genls argument-type)))

;; (defun argument-equal (argument1 argument2) ...) -- active declaration, no body, Cyc API

(defun argument-truth (argument)
  "[Cyc] Return the truth of ARGUMENT."
  (declare (type argument-p argument))
  (if (belief-p argument)
      (belief-truth argument)
      (deduction-truth argument)))

(defun argument-tv (argument)
  "[Cyc] Return the HL tv of ARGUMENT."
  (declare (type argument-p argument))
  (if (belief-p argument)
      (belief-tv argument)
      (tv-from-truth-strength (deduction-truth argument)
                              (deduction-strength argument))))

(defun argument-strength (argument)
  "[Cyc] Return the strength of ARGUMENT."
  (declare (type argument-p argument))
  (if (belief-p argument)
      ;; TODO - belief-strength
      (missing-larkc 31879)
      (deduction-strength argument)))

(defun remove-argument (argument assertion)
  "[Cyc] Remove ARGUMENT from the KB, and unhook it from ASSERTION."
  (if (belief-p argument)
      (remove-belief argument assertion)
      (kb-remove-deduction argument)))

(defun* belief-p (object) (:inline t)
  "[Cyc] Return T iff OBJECT is an HL belief structure."
  (asserted-argument-p object))

;; (defun belief-spec-p (object) ...) -- active declaration, no body
;; (defun belief-to-belief-spec (belief) ...) -- active declaration, no body

(defun* remove-belief (belief assertion) (:inline t)
  (kb-remove-asserted-argument assertion belief))

(defun* belief-truth (belief) (:inline t)
  (asserted-argument-truth belief))

(defun* belief-tv (belief) (:inline t)
  (asserted-argument-tv belief))

;; (defun belief-equal (belief1 belief2) ...) -- active declaration, no body
;; (defun belief-strength (belief) ...) -- active declaration, no body

(defun* asserted-argument-p (object) (:inline t)
  "[Cyc] Return T iff OBJECT is an HL asserted argument structure."
  (asserted-argument-token-p object))

;; (defun asserted-argument-spec-p (object) ...) -- active declaration, no body
;; (defun asserted-argument-to-asserted-argument-spec (asserted-argument) ...) -- active declaration, no body

(defun* create-asserted-argument (assertion tv) (:inline t)
  "[Cyc] Create an asserted argument for ASSERTION with TV."
  (declare (ignore assertion))
  ;; TODO - doesn't this need the assertion?
  (asserted-argument-token-from-tv tv))

(defun* create-asserted-argument-spec (strength-spec) (:inline t)
  (declare (type el-strength-spec-p strength-spec))
  (list :asserted-argument strength-spec))

(defun* asserted-argument-spec-strength-spec (asserted-argument-spec) (:inline t)
  (second asserted-argument-spec))

(defun* kb-remove-asserted-argument-internal (asserted-argument) (:inline t)
  (declare (ignore asserted-argument))
  nil)

;; (defun make-empty-local-support-set () ...) -- active declaration, no body
;; (defun asserted-argument-equal (aa1 aa2) ...) -- active declaration, no body

(deflexical *asserted-argument-tv-table* '((:asserted-true-mon :true-mon)
                                           (:asserted-true-def :true-def)
                                           (:asserted-unknown :unknown)
                                           (:asserted-false-def :false-def)
                                           (:asserted-false-mon :false-mon))
  "[Cyc] Asserted argument -> HL TV mapping.")

(deflexical *asserted-arguments* (mapcar #'first *asserted-argument-tv-table*)
  "[Cyc] Tokens representing the possible asserted arguments.")

(defun* asserted-argument-tokens () (:inline t)
  *asserted-arguments*)

(defun* asserted-argument-token-p (object) (:inline t)
  (member? object *asserted-arguments* #'eq))

(defun* asserted-argument-token-from-tv (tv) (:inline t)
  (declare (type tv-p tv))
  (car (find tv *asserted-argument-tv-table* :test #'eq :key #'second)))

(defun* tv-from-asserted-argument-token (asserted-argument) (:inline t)
  (second (find asserted-argument *asserted-argument-tv-table* :test #'eq :key #'first)))

(defun asserted-argument-tv (asserted-argument)
  (when (asserted-argument-token-p asserted-argument)
    (tv-from-asserted-argument-token asserted-argument)))

(defun* asserted-argument-truth (asserted-argument) (:inline t)
  (tv-truth (asserted-argument-tv asserted-argument)))

;; (defun asserted-argument-strength (asserted-argument) ...) -- active declaration, no body
;; (defun kb-lookup-asserted-argument (assertion truth strength) ...) -- active declaration, no body, Cyc API
;; (defun lookup-asserted-argument (assertion truth strength) ...) -- active declaration, no body
;; (defun list-of-cycl-support-p (object) ...) -- active declaration, no body
;; (defun cycl-support-p (object) ...) -- active declaration, no body

(defun support-p (object)
  "[Cyc] Return T iff OBJECT can be a support in an argument."
  (or (assertion-p object)
      (kb-hl-support-p object)
      (hl-support-p object)))

;; (defun supports-p (object) ...) -- active declaration, no body
;; (defun support-list-p (object) ...) -- active declaration, no body

(defun valid-support? (support &optional robust)
  "[Cyc] Return T if SUPPORT is a valid KB deduction support. ROBUST requests more thorough checking."
  (cond
    ((assertion-p support) (valid-assertion? support))
    ((kb-hl-support-p support) (valid-kb-hl-support? support robust))
    ;; TODO - valid-hl-support-p or valid-hl-support?
    ((hl-support-p support) (missing-larkc 31885))))

;; (defun ill-formed-hl-support? (hl-support) ...) -- active declaration, no body
;; (defun hl-support-syntactically-illformed? (hl-support) ...) -- active declaration, no body
;; (defun kb-hl-support-syntactically-illformed? (kb-hl-support) ...) -- active declaration, no body
;; (defun assertion-syntactically-illformed? (assertion) ...) -- active declaration, no body

(defun support-equal (support1 support2)
  (cond
    ((or (assertion-p support1)
         (assertion-p support2)
         (kb-hl-support-p support1)
         (kb-hl-support-p support2))
     (eq support1 support2))

    (t (equal support1 support2))))


(defun support-< (support1 support2)
  "[Cyc] Imposes an arbitrary but consistent total order between supports."
  (cond
    ((assertion-p support1) (if (assertion-p support2)
                                (if (rule-assertion? support1)
                                    (if (rule-assertion? support2)
                                        (< (assertion-id support1)
                                           (assertion-id support2))
                                        t)
                                    (if (rule-assertion? support2)
                                        nil
                                        (< (assertion-id support1)
                                           (assertion-id support2))))
                                t))
    ((kb-hl-support-p support1) (cond
                                  ((assertion-p support2) nil)
                                  ((kb-hl-support-p support2) (< (kb-hl-support-id support1)
                                                                 (kb-hl-support-id support2)))
                                  (t t)))
    ((or (assertion-p support2)
         (kb-hl-support-p support2))
     nil)
    (t (term-< support1 support2))))

;; (defun sort-supports (supports) ...) -- active declaration, no body

(deflexical *assertion-support-module* :assertion
    "[Cyc] The module which denotes that an assertion is the support.")

(defun support-module (support)
  "[Cyc] Return the module of SUPPORT."
  (declare (type support-p support))
  (cond
    ((assertion-p support) *assertion-support-module*)
    ((kb-hl-support-p support) (missing-larkc 11038))
    (t (hl-support-module support))))

(defun support-sentence (support)
  "[Cyc] Return the sentence of SUPPORT."
  (declare (type support-p support))
  (cond
    ((assertion-p support) (assertion-formula support))
    ((kb-hl-support-p support) (kb-hl-support-sentence support))
    (t (hl-support-sentence support))))

;; (defun support-sentence-operator (support) ...) -- active declaration, no body

(defun* support-formula (support) (:inline t)
  (support-sentence support))

;; (defun support-el-sentence (support) ...) -- active declaration, no body
;; (defun support-ist-sentence (support) ...) -- active declaration, no body
;; (defun support-el-ist-sentence (support) ...) -- active declaration, no body
;; (defun support-cons (support) ...) -- active declaration, no body

(defun support-mt (support)
  "[Cyc] Return the microtheory of SUPPORT."
  (declare (type support-p support))
  (cond
    ((assertion-p support) (assertion-mt support))
    ((kb-hl-support-p support) (missing-larkc 11039))
    (t (hl-support-mt support))))

;; (defun support-elmt (support) ...) -- active declaration, no body

(defun support-justification (support)
  "[Cyc] Return a justification for SUPPORT."
  (cond
    ((assertion-p support) (list support))
    ((kb-hl-support-p support) (missing-larkc 11036))
    (t (hl-support-justify support))))

(defun* support-strength (support) (:inline t)
  "[Cyc] Return the strength of SUPPORT."
  (declare (type support-p support))
  (tv-strength (support-tv support)))

;; (defun support-truth (support) ...) -- active declaration, no body, Cyc API

(defun support-tv (support)
  (cond
    ((assertion-p support) (cyc-assertion-tv support))
    ((kb-hl-support-p support) (kb-hl-support-tv support))
    (t (hl-support-tv support))))

(defun canonicalize-supports (supports &optional (possibly-create-new-kb-hl-supports? t))
  "[Cyc] Return a sorted list of canonicalized supports. This is not destructive."
  (sort (loop for support in supports
           collect (canonicalize-support support possibly-create-new-kb-hl-supports?))
        #'support-<))

(defun canonicalize-support (support &optional (possibly-create-new-kb-hl-supports? t))
  "[Cyc] Canonicalize SUPPORT.  If SUPPORT is an assertion or KB HL support, this simply returns SUPPORT.
   Otherwise, the function attempts to find a KB HL support for SUPPORT or, if POSSIBLY-CREATE-NEW-KB-HL-SUPPORT?
   is non-NIL, it may create a new one."
  (if (or (assertion-p support)
          (kb-hl-support-p support))
      support
      (canonicalize-hl-support support possibly-create-new-kb-hl-supports?)))

(defun canonicalize-hl-support (hl-support &optional (possibly-create-new-kb-hl-supports? t))
  (or (assertion-from-hl-support hl-support)
      (if possibly-create-new-kb-hl-supports?
          (find-or-possibly-create-kb-hl-support hl-support)
          (find-kb-hl-support hl-support))
      hl-support))

(defun hl-support-p (object)
  "[Cyc] Does OBJECT represent an HL support?"
  (and (listp object)
       (proper-list-p object)
       (length= object 4)
       (hl-support-module-p (car object))))

;; [Clyc] Java defines hl-support-module/sentence/mt/tv as four standalone defuns
;; that each do checkType + car/second/third/fourth. Replaced here with a
;; list-typed defstruct that auto-generates the four accessors; the type check
;; the Java performs on each call is dropped as a consequence. Constructor is
;; suppressed because make-hl-support is defined explicitly below.
(defstruct (hl-support (:type list)
                       (:constructor nil))
  module
  sentence
  mt
  tv)

(defun make-hl-support (hl-module sentence &optional (mt *mt*) (tv :true-def))
  "[Cyc] Construct a new HL support."
  (declare (type hl-support-module-p hl-module)
           (type possibly-cycl-sentence-p sentence)
           (type hlmt-p mt)
           (type tv-p tv))
  (list hl-module sentence mt tv))

(defun assertion-from-hl-support (hl-support)
  (when (eq (hl-support-module hl-support) *assertion-support-module*)
    (find-assertion-cycl (hl-support-sentence hl-support)
                         (hl-support-mt hl-support))))

;; (defun hl-support-from-assertion (assertion) ...) -- active declaration, no body
;; (defun valid-hl-support? (hl-support) ...) -- active declaration, no body
;; (defun hl-support-with-module-p (object module) ...) -- active declaration, no body
;; (defun genl-preds-support-p (support) ...) -- active declaration, no body
;; (defun hl-justification-p (object) ...) -- active declaration, no body
;; (defun hl-justification-list-p (object) ...) -- active declaration, no body

(defun non-empty-hl-justification-p (object)
  (and (proper-list-p object)
       (every-in-list #'support-p object)))

;; (defun empty-hl-justification-p (object) ...) -- active declaration, no body

(defun* justification-equal (justification1 justification2) (:inline t)
  (multisets-equal? justification1 justification2 #'support-equal))

(defun* canonicalize-hl-justification (hl-justification) (:inline t)
  (declare (type hl-justification-p hl-justification))
  (sort (copy-list hl-justification) #'support-<))

;; (defun hl-support-justification-p (object) ...) -- active declaration, no body
;; (defun hl-justification-to-hl-support-justification (hl-justification) ...) -- active declaration, no body


;;; Cyc API registrations


(register-cyc-api-function 'argument-p '(object)
    "Return T iff OBJECT is an HL argument structure."
    'nil
    '(booleanp))


(register-cyc-api-function 'argument-equal '(argument1 argument2)
    "Return T iff ARGUMENT1 and ARGUMENT2 are equivalent arguments."
    'nil
    '(booleanp))


(register-cyc-api-function 'argument-truth '(argument)
    "Return the truth of ARGUMENT."
    '((argument argument-p))
    '(truth-p))


(register-cyc-api-function 'argument-strength '(argument)
    "Return the strength of ARGUMENT."
    '((argument argument-p))
    '(el-strength-p))


(register-cyc-api-function 'asserted-argument-p '(object)
    "Return T iff OBJECT is an HL asserted argument structure."
    'nil
    '(booleanp))


(register-cyc-api-function 'kb-lookup-asserted-argument '(assertion truth strength)
    "Return the asserted argument with ASSERTION, TRUTH, and STRENGTH, if it exists.
   Return NIL otherwise."
    '((assertion assertion-p) (truth truth-p) (strength el-strength-p))
    '((nil-or asserted-argument-p)))


(register-cyc-api-function 'support-p '(object)
    "Return T iff OBJECT can be a support in an argument."
    'nil
    '(booleanp))


(register-cyc-api-function 'support-module '(support)
    "Return the module of SUPPORT."
    '((support support-p))
    '(hl-support-module-p))


(register-cyc-api-function 'support-sentence '(support)
    "Return the sentence of SUPPORT."
    '((support support-p))
    '(consp))


(define-obsolete-register 'support-formula '(support-sentence))


(register-cyc-api-function 'support-mt '(support)
    "Return the microtheory of SUPPORT."
    '((support support-p))
    '(hlmt-p))


(register-cyc-api-function 'support-truth '(support)
    "Return the truth of SUPPORT."
    '((support support-p))
    '(truth-p))


(register-cyc-api-function 'support-strength '(support)
    "Return the strength of SUPPORT."
    '((support support-p))
    '(el-strength-p))


(register-cyc-api-function 'hl-support-p '(object)
    "Does OBJECT represent an HL support?"
    'nil
    '(booleanp))


(register-cyc-api-function 'make-hl-support '(hl-module sentence &optional (mt *mt*) (tv :true-def))
    "Construct a new HL support."
    '((hl-module hl-support-module-p) (sentence possibly-cycl-sentence-p) (mt hlmt-p) (tv tv-p))
    '(hl-support-p))
