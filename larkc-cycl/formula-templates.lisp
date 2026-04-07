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

;;; Struct: template-topic
;; Generates: template-topic-p, template-topic-supertopic, template-topic-topic,
;; template-topic-subtopics, template-topic-templates, template-topic-ordering,
;; template-topic-title, template-topic-term-prefix, template-topic-intro-template,
;; template-topic-source-types, template-topic-source-mt, template-topic-query-mt,
;; template-topic-definitional-mt, make-template-topic, and (setf ...) for all slots.
;; Also covers all _csetf-template-topic-* functions.

(defstruct (template-topic (:conc-name "TEMPLATE-TOPIC-"))
  supertopic
  topic
  subtopics
  templates
  ordering
  title
  term-prefix
  intro-template
  source-types
  source-mt
  query-mt
  definitional-mt)

(defconstant *dtp-template-topic* 'template-topic)

(deflexical *cfasl-guid-opcode-template-topic*
  (string-to-guid "18287931-d871-11d9-8eef-0002b3891c5a"))

;;; Struct: arg-position-details
;; Generates: arg-position-details-p, arg-position-details-argument-position,
;; arg-position-details-ordering, arg-position-details-gloss,
;; arg-position-details-invisible-replacement-positions,
;; arg-position-details-replacement-constraints,
;; arg-position-details-candidate-replacements, arg-position-details-is-editable,
;; arg-position-details-explanation, arg-position-details-requires-validation,
;; arg-position-details-unknown-replacement, make-arg-position-details,
;; and (setf ...) for all slots.
;; Also covers all _csetf-arg-position-details-* functions.

(defstruct (arg-position-details (:conc-name "ARG-POSITION-DETAILS-"))
  argument-position
  ordering
  gloss
  invisible-replacement-positions
  replacement-constraints
  candidate-replacements
  is-editable
  explanation
  requires-validation
  unknown-replacement)

(defconstant *dtp-arg-position-details* 'arg-position-details)

(deflexical *cfasl-guid-opcode-arg-position-details*
  (string-to-guid "182a9c10-d871-11d9-8eef-0002b3891c5a"))

;;; Struct: formula-template
;; Generates: formula-template-p, formula-template-topic, formula-template-id,
;; formula-template-formula, formula-template-query-specification,
;; formula-template-elmt, formula-template-focal-term,
;; formula-template-argpos-details, formula-template-argpos-ordering,
;; formula-template-examples, formula-template-entry-format,
;; formula-template-follow-ups, formula-template-gloss, formula-template-refspec,
;; make-formula-template, and (setf ...) for all slots.
;; Also covers all _csetf-formula-template-* functions.

(defstruct (formula-template (:conc-name "FORMULA-TEMPLATE-"))
  topic
  id
  formula
  query-specification
  elmt
  focal-term
  argpos-details
  argpos-ordering
  examples
  entry-format
  follow-ups
  gloss
  refspec)

(defconstant *dtp-formula-template* 'formula-template)

(deflexical *cfasl-guid-opcode-formula-template*
  (string-to-guid "182b1140-d871-11d9-8eef-0002b3891c5a"))

;;; Variables

(defparameter *make-ftemplate-loading-supporting-ask-browsable?* nil)

(defparameter *non-editable-assertions-for-template-topic-instance* nil
  "[Cyc] The bundle of assertions that are not supposed to be made available for editing.")

(defparameter *xml-suppress-future-template-extensions* t
  "[Cyc] A useful switch to test things that should not be made available yet.")

(deflexical *xml-template-topic-revisions*
  '((1 "Adds <templateTopicRevision> to <templateTopic>")
    (0 "Initial version")))

(defparameter *high-to-low-priorities* nil
  "[Cyc] Bound to dictionary mapping terms to lists of lower priority terms.")

(deflexical *warn-on-template-topic-validation-only* t
  "[Cyc] Only emit output that something is bad, dont actually stop.")

(defparameter *template-count-mt* nil) ;; initialized to #$InferencePSC at load time

(deflexical *xml-template-topic-assertions-revisions*
  '((1 "Adds <templateTopicAssertionsRevision> to <knownAssertionsForTemplateTopic>
          Adds <knownAssertionSUIDs> to <knownAssertion>
          Adds <assertion-id> to <knownAssertionSUIDs>
          Adds <bookkeeping-info> to <knownAssertion>
          Adds <date> to <bookkeeping-info>
          Adds <time> to <bookkeeping-info>
          Adds <knownAssertionEvaluations> to <knownAssertion>
          Adds <knownAssertionEvaluation> to <knownAssertionEvaluations>
          Adds <evaluator> to <knownAssertionEvaluation>
          Adds <judgment> to <knownAssertionEvaluation>")
    (0 "Initial version")))

(deflexical *quaternary-fet-evaluation-pred* nil)

(deflexical *map-elmt-to-published-conceptual-work-caching-state* nil)

;; Note: ?I intentionally omitted (traditional convention to avoid confusion with 1)
(deflexical *unique-variables-list-for-formula-templates*
  '(?a ?b ?c ?d ?e ?f ?g ?h ?j ?k ?l ?m ?n ?o ?p ?q ?r ?s ?t ?u ?v ?w ?x ?y ?z))

(deflexical *elmt-variable-for-formula-templates* '?poly-elmt)

(defparameter *get-assertions-from-initial-ask?* t
  "[Cyc] BOOLEANP; Should we try to get assertion objects via our first ask, as opposed
to finding bindings, substituting, and then looking for matching assertions?")

(deflexical *ftemplate-constraint-to-collection-skiplist* nil) ;; initialized in setup

;;; Declare section — following declare_formula_templates_file order

;; template-topic-print-function-trampoline — active declareFunction, missing-larkc 5848
(defun template-topic-print-function-trampoline (object stream)
  "[Cyc] Trampoline for print method."
  (declare (ignore object stream))
  (missing-larkc 5848))

;; template-topic-p — provided by defstruct
;; template-topic-supertopic — provided by defstruct
;; template-topic-topic — provided by defstruct
;; template-topic-subtopics — provided by defstruct
;; template-topic-templates — provided by defstruct
;; template-topic-ordering — provided by defstruct
;; template-topic-title — provided by defstruct
;; template-topic-term-prefix — provided by defstruct
;; template-topic-intro-template — provided by defstruct
;; template-topic-source-types — provided by defstruct
;; template-topic-source-mt — provided by defstruct
;; template-topic-query-mt — provided by defstruct
;; template-topic-definitional-mt — provided by defstruct
;; _csetf-template-topic-supertopic — provided by defstruct (setf template-topic-supertopic)
;; _csetf-template-topic-topic — provided by defstruct (setf template-topic-topic)
;; _csetf-template-topic-subtopics — provided by defstruct (setf template-topic-subtopics)
;; _csetf-template-topic-templates — provided by defstruct (setf template-topic-templates)
;; _csetf-template-topic-ordering — provided by defstruct (setf template-topic-ordering)
;; _csetf-template-topic-title — provided by defstruct (setf template-topic-title)
;; _csetf-template-topic-term-prefix — provided by defstruct (setf template-topic-term-prefix)
;; _csetf-template-topic-intro-template — provided by defstruct (setf template-topic-intro-template)
;; _csetf-template-topic-source-types — provided by defstruct (setf template-topic-source-types)
;; _csetf-template-topic-source-mt — provided by defstruct (setf template-topic-source-mt)
;; _csetf-template-topic-query-mt — provided by defstruct (setf template-topic-query-mt)
;; _csetf-template-topic-definitional-mt — provided by defstruct (setf template-topic-definitional-mt)
;; make-template-topic — provided by defstruct

;; arg-position-details-print-function-trampoline — active declareFunction, missing-larkc 5845
(defun arg-position-details-print-function-trampoline (object stream)
  "[Cyc] Trampoline for print method."
  (declare (ignore object stream))
  (missing-larkc 5845))

;; arg-position-details-p — provided by defstruct
;; arg-position-details-argument-position — provided by defstruct
;; arg-position-details-ordering — provided by defstruct
;; arg-position-details-gloss — provided by defstruct
;; arg-position-details-invisible-replacement-positions — provided by defstruct
;; arg-position-details-replacement-constraints — provided by defstruct
;; arg-position-details-candidate-replacements — provided by defstruct
;; arg-position-details-is-editable — provided by defstruct
;; arg-position-details-explanation — provided by defstruct
;; arg-position-details-requires-validation — provided by defstruct
;; arg-position-details-unknown-replacement — provided by defstruct
;; _csetf-arg-position-details-argument-position — provided by defstruct (setf ...)
;; _csetf-arg-position-details-ordering — provided by defstruct (setf ...)
;; _csetf-arg-position-details-gloss — provided by defstruct (setf ...)
;; _csetf-arg-position-details-invisible-replacement-positions — provided by defstruct (setf ...)
;; _csetf-arg-position-details-replacement-constraints — provided by defstruct (setf ...)
;; _csetf-arg-position-details-candidate-replacements — provided by defstruct (setf ...)
;; _csetf-arg-position-details-is-editable — provided by defstruct (setf ...)
;; _csetf-arg-position-details-explanation — provided by defstruct (setf ...)
;; _csetf-arg-position-details-requires-validation — provided by defstruct (setf ...)
;; _csetf-arg-position-details-unknown-replacement — provided by defstruct (setf ...)
;; make-arg-position-details — provided by defstruct

;; formula-template-print-function-trampoline — active declareFunction, missing-larkc 5847
(defun formula-template-print-function-trampoline (object stream)
  "[Cyc] Trampoline for print method."
  (declare (ignore object stream))
  (missing-larkc 5847))

;; formula-template-p — provided by defstruct
;; formula-template-topic — provided by defstruct
;; formula-template-id — provided by defstruct
;; formula-template-formula — provided by defstruct
;; formula-template-query-specification — provided by defstruct
;; formula-template-elmt — provided by defstruct
;; formula-template-focal-term — provided by defstruct
;; formula-template-argpos-details — provided by defstruct
;; formula-template-argpos-ordering — provided by defstruct
;; formula-template-examples — provided by defstruct
;; formula-template-entry-format — provided by defstruct
;; formula-template-follow-ups — provided by defstruct
;; formula-template-gloss — provided by defstruct
;; formula-template-refspec — provided by defstruct
;; _csetf-formula-template-topic — provided by defstruct (setf ...)
;; _csetf-formula-template-id — provided by defstruct (setf ...)
;; _csetf-formula-template-formula — provided by defstruct (setf ...)
;; _csetf-formula-template-query-specification — provided by defstruct (setf ...)
;; _csetf-formula-template-elmt — provided by defstruct (setf ...)
;; _csetf-formula-template-focal-term — provided by defstruct (setf ...)
;; _csetf-formula-template-argpos-details — provided by defstruct (setf ...)
;; _csetf-formula-template-argpos-ordering — provided by defstruct (setf ...)
;; _csetf-formula-template-examples — provided by defstruct (setf ...)
;; _csetf-formula-template-entry-format — provided by defstruct (setf ...)
;; _csetf-formula-template-follow-ups — provided by defstruct (setf ...)
;; _csetf-formula-template-gloss — provided by defstruct (setf ...)
;; _csetf-formula-template-refspec — provided by defstruct (setf ...)
;; make-formula-template — provided by defstruct

;; (defun is-ftemplate-loading-supporting-ask-browsable? () ...) -- commented declareFunction, no body (0 0)

;; Macro: with-browsable-ftemplate-loading-supporting-ask
;; Reconstructed from Internal Constants: $sym133$CLET, $list134 binding
;; (*MAKE-FTEMPLATE-LOADING-SUPPORTING-ASK-BROWSABLE?* T).
(defmacro with-browsable-ftemplate-loading-supporting-ask (&body body)
  `(clet ((*make-ftemplate-loading-supporting-ask-browsable?* t))
     ,@body))

;; TODO - Macro: reusing-rkf-sd-problem-store-if-available
;; No clear arglist or expansion evidence in Internal Constants to reconstruct.

;; (defun get-non-editable-assertions-for-template-topic-instance () ...) -- commented declareFunction, no body (0 0)

;; Macro: with-known-non-editable-assertions-for-template-topic-instance
;; Reconstructed from Internal Constants: $list136 arglist ((NON-EDITABLES) &BODY BODY),
;; $sym138 CHECK-TYPE, $list139 (SET-P), $sym137 *NON-EDITABLE-ASSERTIONS-FOR-TEMPLATE-TOPIC-INSTANCE*.
(defmacro with-known-non-editable-assertions-for-template-topic-instance ((non-editables) &body body)
  `(progn
     (check-type ,non-editables set-p)
     (clet ((*non-editable-assertions-for-template-topic-instance* ,non-editables))
       ,@body)))

;; (defun compute-non-editable-assertions-for-template-topic-instance (instance template-id template-elmt query-mt) ...) -- commented declareFunction, no body (4 0)
;; (defun is-non-editable-assertion-for-template-topic-instance? (assertion) ...) -- commented declareFunction, no body (1 0)

;; Macro: with-non-editable-assertions-for-template-topic-instance
;; Reconstructed from Internal Constants: $list140 arglist
;; ((INSTANCE TEMPLATE-ID TEMPLATE-ELMT QUERY-MT) &BODY BODY),
;; $sym141 uninternedSymbol NON-EDITABLE (gensym),
;; $sym142 COMPUTE-NON-EDITABLE-ASSERTIONS-FOR-TEMPLATE-TOPIC-INSTANCE,
;; $sym143 WITH-KNOWN-NON-EDITABLE-ASSERTIONS-FOR-TEMPLATE-TOPIC-INSTANCE.
(defmacro with-non-editable-assertions-for-template-topic-instance ((instance template-id template-elmt query-mt) &body body)
  (let ((non-editable (gensym "NON-EDITABLE")))
    `(let ((,non-editable (compute-non-editable-assertions-for-template-topic-instance
                           ,instance ,template-id ,template-elmt ,query-mt)))
       (with-known-non-editable-assertions-for-template-topic-instance (,non-editable)
         ,@body))))

;; (defun valid-formula-template-p (object) ...) -- commented declareFunction, no body (1 0)
;; (defun new-template-topic (topic &optional supertopic) ...) -- commented declareFunction, no body (1 1)
;; (defun template-topic-add-subtopic (template-topic subtopic) ...) -- commented declareFunction, no body (2 0)
;; (defun template-topic-add-template (template-topic template) ...) -- commented declareFunction, no body (2 0)
;; (defun template-topic-add-title (template-topic title) ...) -- commented declareFunction, no body (2 0)
;; (defun template-topic-add-term-prefix (template-topic prefix) ...) -- commented declareFunction, no body (2 0)
;; (defun template-topic-set-introductory-template (template-topic template) ...) -- commented declareFunction, no body (2 0)
;; (defun template-topic-set-source-types (template-topic types) ...) -- commented declareFunction, no body (2 0)
;; (defun print-template-topic (object stream depth) ...) -- commented declareFunction, no body (3 0)
;; (defun xml-template-topic-current-revision () ...) -- commented declareFunction, no body (0 0)
;; (defun xml-serialize-template-topic (topic &optional stream) ...) -- commented declareFunction, no body (1 1)

;; cfasl-output-object-template-topic-method — active declareFunction, missing-larkc 5671
(defun cfasl-output-object-template-topic-method (object stream)
  "[Cyc] CFASL output method for template-topic objects."
  (declare (ignore object stream))
  (missing-larkc 5671))

;; (defun cfasl-output-template-topic (object stream) ...) -- commented declareFunction, no body (2 0)
;; (defun cfasl-input-template-topic (stream) ...) -- commented declareFunction, no body (1 0)
;; (defun new-formula-template (topic &optional id) ...) -- commented declareFunction, no body (1 1)
;; (defun formula-template-is-single-entry? (template) ...) -- commented declareFunction, no body (1 0)
;; (defun formula-template-is-multiple-entry? (template) ...) -- commented declareFunction, no body (1 0)
;; (defun formula-template-has-reformulation-specification? (template) ...) -- commented declareFunction, no body (1 0)
;; (defun print-formula-template (object stream depth) ...) -- commented declareFunction, no body (3 0)
;; (defun formula-template-set-formula (template formula) ...) -- commented declareFunction, no body (2 0)
;; (defun formula-template-set-examples (template examples) ...) -- commented declareFunction, no body (2 0)
;; (defun formula-template-set-focal-term (template term) ...) -- commented declareFunction, no body (2 0)
;; (defun formula-template-set-elmt (template elmt) ...) -- commented declareFunction, no body (2 0)
;; (defun formula-template-set-entry-format (template format) ...) -- commented declareFunction, no body (2 0)
;; (defun formula-template-set-gloss (template gloss) ...) -- commented declareFunction, no body (2 0)
;; (defun formula-template-set-query-specification (template spec) ...) -- commented declareFunction, no body (2 0)
;; (defun xml-serialize-formula-template (template &optional stream) ...) -- commented declareFunction, no body (1 1)
;; (defun xml-serialize-formula-template-as-document (template &optional stream) ...) -- commented declareFunction, no body (1 1)
;; (defun xml-serialize-formula-template-header (&optional stream) ...) -- commented declareFunction, no body (0 1)

;; cfasl-output-object-formula-template-method — active declareFunction, missing-larkc 5670
(defun cfasl-output-object-formula-template-method (object stream)
  "[Cyc] CFASL output method for formula-template objects."
  (declare (ignore object stream))
  (missing-larkc 5670))

;; (defun cfasl-output-formula-template (object stream) ...) -- commented declareFunction, no body (2 0)
;; (defun cfasl-input-formula-template (stream) ...) -- commented declareFunction, no body (1 0)
;; (defun new-arg-position-details (position) ...) -- commented declareFunction, no body (1 0)
;; (defun valid-arg-position-details-p (object) ...) -- commented declareFunction, no body (1 0)
;; (defun print-arg-position-details (object stream depth) ...) -- commented declareFunction, no body (3 0)
;; (defun xml-serialize-arg-position-details (details &optional stream) ...) -- commented declareFunction, no body (1 1)

;; cfasl-output-object-arg-position-details-method — active declareFunction, missing-larkc 5669
(defun cfasl-output-object-arg-position-details-method (object stream)
  "[Cyc] CFASL output method for arg-position-details objects."
  (declare (ignore object stream))
  (missing-larkc 5669))

;; (defun cfasl-output-arg-position-details (object stream) ...) -- commented declareFunction, no body (2 0)
;; (defun cfasl-input-arg-position-details (stream) ...) -- commented declareFunction, no body (1 0)
;; (defun xml-serialize-arg-position (position &optional stream) ...) -- commented declareFunction, no body (1 1)
;; (defun formula-template-load-topic-template-details (topic templates mt) ...) -- commented declareFunction, no body (3 0)
;; (defun ftemplate-load-argument-position-detail-information (template mt &optional details) ...) -- commented declareFunction, no body (2 1)
;; (defun update-ftemplate-argpos-detail-glosses (template mt) ...) -- commented declareFunction, no body (2 0)
;; (defun update-ftemplate-argpos-detail-explanations (template mt) ...) -- commented declareFunction, no body (2 0)
;; (defun update-ftemplate-argpos-detail-invisible-replacement-positions (template mt) ...) -- commented declareFunction, no body (2 0)
;; (defun update-ftemplate-argpos-detail-replacable-positions (template mt) ...) -- commented declareFunction, no body (2 0)
;; (defun update-ftemplate-argpos-detail-replacement-constraints (template mt) ...) -- commented declareFunction, no body (2 0)
;; (defun update-ftemplate-argpos-detail-candidate-replacements (template mt) ...) -- commented declareFunction, no body (2 0)
;; (defun update-ftemplate-argpos-detail-validation-required (template mt) ...) -- commented declareFunction, no body (2 0)
;; (defun update-ftemplate-argpos-detail-unknown-replacements (template mt) ...) -- commented declareFunction, no body (2 0)
;; (defun get-ftemplate-arg-position-details (template position) ...) -- commented declareFunction, no body (2 0)
;; (defun update-ftemplate-argpos-detail-ordering-information (template) ...) -- commented declareFunction, no body (1 0)
;; (defun ftemplate-compute-ordering-of-argpos-details (template mt) ...) -- commented declareFunction, no body (2 0)
;; (defun sort-argpos-details-by-ordering (details) ...) -- commented declareFunction, no body (1 0)
;; (defun ordered-by-argument-position (a b) ...) -- commented declareFunction, no body (2 0)
;; (defun load-formula-template-skeleton-from-kb (template mt) ...) -- commented declareFunction, no body (2 0)
;; (defun load-formula-template-details-from-kb (template mt) ...) -- commented declareFunction, no body (2 0)
;; (defun ftemplate-assign-formula-component (template mt) ...) -- commented declareFunction, no body (2 0)
;; (defun ftemplate-get-functional-slot-value (template pred mt) ...) -- commented declareFunction, no body (3 0)
;; (defun ftemplate-get-template-reformulation-specification (template mt) ...) -- commented declareFunction, no body (2 0)
;; (defun ftemplate-get-query-specification (template mt) ...) -- commented declareFunction, no body (2 0)
;; (defun ftemplate-get-template-formula (template mt) ...) -- commented declareFunction, no body (2 0)
;; (defun ftemplate-get-template-elmt (template mt) ...) -- commented declareFunction, no body (2 0)
;; (defun ftemplate-get-template-follow-ups (template mt) ...) -- commented declareFunction, no body (2 0)
;; (defun ftemplate-get-template-gloss (template mt) ...) -- commented declareFunction, no body (2 0)
;; (defun ftemplate-qualify-mt-to-now (mt) ...) -- commented declareFunction, no body (1 0)
;; (defun ftemplate-qualify-mt-to-anytime (mt) ...) -- commented declareFunction, no body (1 0)
;; (defun ftemplate-hlmt-change-time (hlmt time) ...) -- commented declareFunction, no body (2 0)
;; (defun ftemplate-get-template-glosses (template mt argpos) ...) -- commented declareFunction, no body (3 0)
;; (defun ftemplate-get-template-explanations (template mt argpos) ...) -- commented declareFunction, no body (3 0)
;; (defun ftemplate-get-template-examples (template mt argpos) ...) -- commented declareFunction, no body (3 0)
;; (defun ftemplate-get-first-asserted-value (template pred index mt &optional index2 value-pos index-pos index2-pos) ...) -- commented declareFunction, no body (4 4)
;; (defun ftemplate-get-asserted-values (template pred index mt &optional value-pos index-pos index2 index2-pos gather-pos) ...) -- commented declareFunction, no body (4 5)
;; (defun ftemplate-get-template-focal-term (template mt pred) ...) -- commented declareFunction, no body (3 0)
;; (defun ftemplate-get-template-format (template mt pred) ...) -- commented declareFunction, no body (3 0)
;; (defun ftemplate-get-template-invisible-replacement-positions (template mt pred) ...) -- commented declareFunction, no body (3 0)
;; (defun ftemplate-get-template-replacement-constraints (template mt) ...) -- commented declareFunction, no body (2 0)
;; (defun ftemplate-get-template-unknown-replacements (template mt) ...) -- commented declareFunction, no body (2 0)
;; (defun ftemplate-get-template-candidate-replacements-for-position (template mt) ...) -- commented declareFunction, no body (2 0)
;; (defun ftemplate-get-template-replacable-positions (template mt) ...) -- commented declareFunction, no body (2 0)
;; (defun ftemplate-get-template-validation-requirements (template mt) ...) -- commented declareFunction, no body (2 0)
;; (defun formula-template-load-topic-subtopic-ordering (topic mt) ...) -- commented declareFunction, no body (2 0)
;; (defun formula-template-load-topic-template-ordering (topic mt) ...) -- commented declareFunction, no body (2 0)
;; (defun lower-priority-terms (term) ...) -- commented declareFunction, no body (1 0)
;; (defun accumulate-lower-priority-terms (term lower) ...) -- commented declareFunction, no body (2 0)
;; (defun higher-priority? (a b) ...) -- commented declareFunction, no body (2 0)
;; (defun apply-prioritizing-ordering-to-kb-objects (ordering objects) ...) -- commented declareFunction, no body (2 0)
;; (defun apply-prioritizing-ordering-to-kb-objects-rck (ordering objects) ...) -- commented declareFunction, no body (2 0)
;; (defun construct-high/low-information-from-prioritizing-ordering (ordering) ...) -- commented declareFunction, no body (1 0)
;; (defun formula-template-load-prioritization-information-for-subtopics (topic mt) ...) -- commented declareFunction, no body (2 0)
;; (defun formula-template-load-prioritization-information-for-templates (topic mt) ...) -- commented declareFunction, no body (2 0)
;; (defun formula-template-organize-templates-by-ordering (topic) ...) -- commented declareFunction, no body (1 0)
;; (defun formula-template-organize-subtopics-by-ordering (topic) ...) -- commented declareFunction, no body (1 0)
;; (defun formula-template-organize-by-ordering (topic accessor setter) ...) -- commented declareFunction, no body (3 0)
;; (defun stable-template-id-compare (a b) ...) -- commented declareFunction, no body (2 0)
;; (defun formula-template-load-template-graph (topic mt) ...) -- commented declareFunction, no body (2 0)
;; (defun validate-template-topic-semantic-constraints (topic) ...) -- commented declareFunction, no body (1 0)
;; (defun template-topic-query-mt-can-see-all-assertion-mts (topic) ...) -- commented declareFunction, no body (1 0)
;; (defun check-template-topic-query-mt-can-see-subtopics-assertion-mts (topic mt) ...) -- commented declareFunction, no body (2 0)
;; (defun templates-use-isa/genls? () ...) -- commented declareFunction, no body (0 0)
;; (defun asserted-formula-template-ids-for-type (type mt) ...) -- commented declareFunction, no body (2 0)
;; (defun sort-formula-template-subtopics-by-template-count (subtopics mt) ...) -- commented declareFunction, no body (2 0)
;; (defun count-asserted-formula-template-ids-for-type-internal (type &optional mt) ...) -- commented declareFunction, no body (1 1)
;; (defun count-asserted-formula-template-ids-for-type (type &optional mt) ...) -- commented declareFunction, no body (1 1)
;; (defun fet-topic-fort-has-subtopics? (topic mt) ...) -- commented declareFunction, no body (2 0)
;; (defun fet-topic-fort-has-templates? (topic mt) ...) -- commented declareFunction, no body (2 0)
;; (defun formula-template-subtopics-for-type (type mt) ...) -- commented declareFunction, no body (2 0)
;; (defun formula-template-asserted-subtopics-for-type (type mt) ...) -- commented declareFunction, no body (2 0)
;; (defun asserted-formula-template-subtopics-for-type (type mt) ...) -- commented declareFunction, no body (2 0)
;; (defun formula-template-induction-mt (topic mt) ...) -- commented declareFunction, no body (2 0)
;; (defun formula-template-topic-load-topic-specifics (topic mt) ...) -- commented declareFunction, no body (2 0)
;; (defun topictmplt-get-topic-template-source-types (topic mt) ...) -- commented declareFunction, no body (2 0)
;; (defun ftemplate-topic-get-functional-slot-value (topic pred mt) ...) -- commented declareFunction, no body (3 0)
;; (defun topictmplt-get-topic-template-introductory-template (topic mt) ...) -- commented declareFunction, no body (2 0)
;; (defun topictmplt-get-topic-template-title (topic mt) ...) -- commented declareFunction, no body (2 0)
;; (defun topictmplt-get-topic-template-term-prefix (topic mt) ...) -- commented declareFunction, no body (2 0)
;; (defun topictmplt-get-topic-template-query-mt (topic mt) ...) -- commented declareFunction, no body (2 0)
;; (defun topictmplt-get-topic-template-definitional-mt (topic mt) ...) -- commented declareFunction, no body (2 0)
;; (defun ftemplate-ask-variable (template mt pred &optional arg) ...) -- commented declareFunction, no body (3 1)
;; (defun ftemplate-ask-template (template mt query &optional arg) ...) -- commented declareFunction, no body (3 1)
;; (defun get-editable-and-non-editable-assertions-for-template-topic-instance (topic instance mt) ...) -- commented declareFunction, no body (3 0)
;; (defun get-assertions-for-template-topic-instance (topic instance mt) ...) -- commented declareFunction, no body (3 0)
;; (defun get-assertions-for-template-topic-instance-int (topic instance mt non-editables) ...) -- commented declareFunction, no body (4 0)
;; (defun xml-template-topic-assertions-current-revision () ...) -- commented declareFunction, no body (0 0)
;; (defun xml-serialize-assertions-for-template-topic-instance (topic instance mt elmt &optional query-mt stream) ...) -- commented declareFunction, no body (5 1)
;; (defun xml-serialize-assertions-for-formula-template-instance (template instance mt &optional stream) ...) -- commented declareFunction, no body (3 1)
;; (defun ftemplate-assertion-non-editable? (assertion template) ...) -- commented declareFunction, no body (2 0)
;; (defun xml-serialize-assertion-for-formula-template-instance (assertion template stream) ...) -- commented declareFunction, no body (3 0)
;; (defun xml-serialize-assertion-sentence-for-formula-template-instance (assertion template stream) ...) -- commented declareFunction, no body (3 0)
;; (defun xml-serialize-assertion-suids-for-formula-template-instance (assertion template mt stream) ...) -- commented declareFunction, no body (4 0)
;; (defun ftemplate-polycanonicalized-assertion-suids (assertion mt) ...) -- commented declareFunction, no body (2 0)
;; (defun xml-serialize-assertion-evaluation-data-for-formula-template-instance (assertion template mt stream) ...) -- commented declareFunction, no body (4 0)
;; (defun quaternary-fet-evaluation-pred () ...) -- commented declareFunction, no body (0 0)
;; (defun ftemplate-assertion-evaluations (assertion template mt) ...) -- commented declareFunction, no body (3 0)
;; (defun ftemplate-evaluation-judgment (evaluation) ...) -- commented declareFunction, no body (1 0)
;; (defun xml-serialize-assertion-timestamp-for-formula-template-instance (assertion template mt stream) ...) -- commented declareFunction, no body (4 0)
;; (defun ftemplate-polycanonicalized-assertion-date (assertion mt) ...) -- commented declareFunction, no body (2 0)
;; (defun ftemplate-polycanonicalized-assertion-second (assertion mt) ...) -- commented declareFunction, no body (2 0)
;; (defun xml-serialize-assertion-elmt-for-formula-template-instance (assertion template stream) ...) -- commented declareFunction, no body (3 0)
;; (defun xml-serialize-elmt-information-for-assertion (elmt &optional stream) ...) -- commented declareFunction, no body (1 1)
;; (defun clear-map-elmt-to-published-conceptual-work () ...) -- commented declareFunction, no body (0 0)
;; (defun remove-map-elmt-to-published-conceptual-work (elmt) ...) -- commented declareFunction, no body (1 0)
;; (defun map-elmt-to-published-conceptual-work-internal (elmt) ...) -- commented declareFunction, no body (1 0)
;; (defun map-elmt-to-published-conceptual-work (elmt) ...) -- commented declareFunction, no body (1 0)
;; (defun get-assertions-for-leaf-template-topic-instance (topic instance mt non-editables) ...) -- commented declareFunction, no body (4 0)
;; (defun get-assertions-for-formula-template-instance (template instance mt non-editables) ...) -- commented declareFunction, no body (4 0)
;; (defun get-assertions-for-fet-sentence (sentence instance mt elmt non-editables &optional query-spec refspec reformulated-mt) ...) -- commented declareFunction, no body (5 3)
;; (defun fet-fallback-to-default-mt? (mt) ...) -- commented declareFunction, no body (1 0)
;; (defun ftemplate-reformulated-query-mt (template mt) ...) -- commented declareFunction, no body (2 0)
;; (defun ftemplate-filter-reformulated-result-set (results template) ...) -- commented declareFunction, no body (2 0)
;; (defun ftemplate-reformulated-result-duplicate? (result results) ...) -- commented declareFunction, no body (2 0)
;; (defun unpack-note-reformulation-result-sets (results sentence mt) ...) -- commented declareFunction, no body (3 0)
;; (defun add-one-polycanonicalized-result (result results) ...) -- commented declareFunction, no body (2 0)
;; (defun unpack-note-reformulation-result (result sentence mt) ...) -- commented declareFunction, no body (3 0)
;; (defun ftemplate-loading-supporting-ask (sentence mt template &optional ask-properties) ...) -- commented declareFunction, no body (3 1)
;; (defun smarter-find-visible-assertions-cycl (sentence mt) ...) -- commented declareFunction, no body (2 0)
;; (defun get-assertions-from-formula-template-result-sets (result-sets sentence instance mt &optional non-editables elmt) ...) -- commented declareFunction, no body (5 1)
;; (defun make-ftemplate-polycanonicalized-assertion (sentence mt &optional assertions) ...) -- commented declareFunction, no body (2 1)
;; (defun ftemplate-polycanonicalized-assertion-p (object) ...) -- commented declareFunction, no body (1 0)
;; (defun ftemplate-polycanonicalized-assertion-sentence (assertion) ...) -- commented declareFunction, no body (1 0)
;; (defun ftemplate-polycanonicalized-assertion-hl-assertions (assertion mt) ...) -- commented declareFunction, no body (2 0)
;; (defun ftemplate-polycanonicalized-assertion-find-hl-assertions (assertion mt) ...) -- commented declareFunction, no body (2 0)
;; (defun ftemplate-polycanonicalized-assertion-mt (assertion) ...) -- commented declareFunction, no body (1 0)
;; (defun ftemplate-assertion-mt (assertion) ...) -- commented declareFunction, no body (1 0)
;; (defun bad-assertion-for-formula-templates? (assertion) ...) -- commented declareFunction, no body (1 0)
;; (defun uninteresting-indeterminate-term? (term) ...) -- commented declareFunction, no body (1 0)
;; (defun is-skolemish-term? (term) ...) -- commented declareFunction, no body (1 0)
;; (defun get-assertion-sentence-and-constraints-from-formula-template (template instance mt) ...) -- commented declareFunction, no body (3 0)
;; (defun get-assertion-finding-query-sentence (sentence &optional variable) ...) -- commented declareFunction, no body (1 1)
;; (defun constrain-query-with-accumulated-constraints (query constraints) ...) -- commented declareFunction, no body (2 0)
;; (defun fet-assertion-variable-for-formula (formula) ...) -- commented declareFunction, no body (1 0)
;; (defun ftemplate-assertion-constrained-query-formula (formula &optional constraints) ...) -- commented declareFunction, no body (1 1)
;; (defun formula-ok-for-fet-assertion-var? (formula variable) ...) -- commented declareFunction, no body (2 0)
;; (defun convert-ftemplate-input-constraint-to-collection (constraint mt) ...) -- commented declareFunction, no body (2 0)
;; (defun get-lexical-mt-for-rkf-interaction-mt (mt) ...) -- commented declareFunction, no body (1 0)

;;; Setup

(toplevel
  ;; CFASL GUID input function registrations
  (register-cfasl-guid-denoted-type-input-function
   *cfasl-guid-opcode-template-topic* 'cfasl-input-template-topic)
  (register-cfasl-guid-denoted-type-input-function
   *cfasl-guid-opcode-arg-position-details* 'cfasl-input-arg-position-details)
  (register-cfasl-guid-denoted-type-input-function
   *cfasl-guid-opcode-formula-template* 'cfasl-input-formula-template)
  ;; Memoization
  (note-memoized-function 'count-asserted-formula-template-ids-for-type)
  (note-globally-cached-function 'map-elmt-to-published-conceptual-work))

;; CFASL output dispatch — Java uses Structures.register_method on
;; *cfasl-output-object-method-table*; CL port uses defmethod on the
;; cfasl-output-object generic function.
(defmethod cfasl-output-object ((object template-topic) stream)
  (cfasl-output-object-template-topic-method object stream))

(defmethod cfasl-output-object ((object formula-template) stream)
  (cfasl-output-object-formula-template-method object stream))

(defmethod cfasl-output-object ((object arg-position-details) stream)
  (cfasl-output-object-arg-position-details-method object stream))
