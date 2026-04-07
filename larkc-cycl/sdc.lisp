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

;;; Macros (commented-out declareMacro entries)

;; with-sbhl-sd-marking-spaces - macro, no body
;; with-sbhl-sd-genls-isas-spaces - macro, no body

;;; Variables

(defparameter *sdc-exception-transfers-thru-specs?* nil
  "[Cyc] should sdc module support (expensive) rule (-> (and (sdcException x y) (genls z y)) (sdcException x z))?")

(defparameter *sdc-common-spec-exception?* nil
  "[Cyc] should sdc module support (expensive) rule (-> (and (genls z x) (genls z y)) (sdcException x y))")

(defparameter *ignoring-sdc?* nil
  "[Cyc] ignore sdc module while recomputing sbhl links?")

(defparameter *sd-c1-genls-space* nil
  "[Cyc] the genls of c1 during sd queries")

(defparameter *sd-c2-genls-space* nil
  "[Cyc] the genls of c2 during sd quries")

(defparameter *sd-genls-isas-space* nil
  "[Cyc] the isas or the genls of c1 durign sd queries")

(defparameter *sd-candidate-store* nil
  "[Cyc] record of encountered sdc candidates and their exceptions")

;;; Functions (ordered by declare_sdc_file)

(defun any-isa-common-sdct (c1 c2 &optional mt tv)
  "[Cyc] Returns the first common sibling-disjoint collection type for C1 and C2."
  (let ((result nil)
        (exception? nil))
    (let ((*mt* (update-inference-mt-relevance-mt mt))
          (*relevant-mt-function* (update-inference-mt-relevance-function mt))
          (*relevant-mts* (update-inference-mt-relevance-mt-list mt)))
      (let ((*sbhl-tv* (if tv tv (get-sbhl-true-tv)))
            (*relevant-sbhl-tv-function* (if tv
                                             'relevant-sbhl-tv-is-general-tv
                                             *relevant-sbhl-tv-function*)))
        (when tv
          (when (sbhl-object-type-checking-p)
            (unless (sbhl-true-tv-p tv)
              (let ((pcase-var *sbhl-type-error-action*))
                (cond
                  ((eql pcase-var :error)
                   (sbhl-error 1 "~A is not a ~A" tv 'sbhl-true-tv-p))
                  ((eql pcase-var :cerror)
                   ;; missing-larkc 2229 likely calls sbhl-cerror for type check
                   (missing-larkc 2229))
                  ((eql pcase-var :warn)
                   (warn "~A is not a ~A" tv 'sbhl-true-tv-p))
                  (t
                   (warn "~A is not a valid *sbhl-type-error-action* value"
                         *sbhl-type-error-action*)
                   (cerror "continue anyway"
                           "~A is not a ~A" tv 'sbhl-true-tv-p)))))))
        (let ((*sd-c1-genls-space* (get-sbhl-marking-space)))
          (let ((*sd-c2-genls-space* (get-sbhl-marking-space)))
            (let ((*sd-genls-isas-space* (get-sbhl-marking-space)))
              (let ((*sd-candidate-store* (get-sbhl-marking-space)))
                (sbhl-mark-sd-c1-genls-and-non-c2-genls-isas c1 c2)
                (let* ((module (get-sbhl-module #$genls))
                       (*sbhl-search-module* module)
                       (*sbhl-search-module-type* (get-sbhl-module-type module))
                       (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
                       (*genl-inverse-mode-p* nil)
                       (*sbhl-module* module)
                       (*sbhl-search-behavior* (determine-sbhl-search-behavior
                                                (get-sbhl-search-module)
                                                (get-sbhl-search-direction)
                                                (get-sbhl-tv)))
                       (*sbhl-terminating-marking-space* (determine-sbhl-terminating-marking-space
                                                          *sbhl-search-behavior*)))
                  (setf exception? (or (sbhl-search-path-termination-p c1 *sd-c2-genls-space*)
                                       (sbhl-search-path-termination-p c2 *sd-c1-genls-space*))))
                (unless exception?
                  (when *sdc-exception-transfers-thru-specs?*
                    (let* ((module (get-sbhl-module #$genls))
                           (*sbhl-search-module* module)
                           (*sbhl-search-module-type* (get-sbhl-module-type module))
                           (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
                           (*genl-inverse-mode-p* nil)
                           (*sbhl-module* module)
                           (*sbhl-search-behavior* (determine-sbhl-search-behavior
                                                    (get-sbhl-search-module)
                                                    (get-sbhl-search-direction)
                                                    (get-sbhl-tv)))
                           (*sbhl-terminating-marking-space* (determine-sbhl-terminating-marking-space
                                                              *sbhl-search-behavior*)))
                      (unless exception?
                        (catch :do-hash-table
                          (maphash (lambda (c2-genl val)
                                     (declare (ignore val))
                                     ;; missing-larkc 4756, likely checks c2-genl relevance
                                     (missing-larkc 4756)
                                     (let ((exceptions (direct-sdc-exceptions c2-genl)))
                                       (unless exception?
                                         (dolist (exception exceptions)
                                           (when exception?
                                             (return))
                                           (when (sbhl-search-path-termination-p exception *sd-c1-genls-space*)
                                             (setf exception? t))))))
                                   *sd-c2-genls-space*)))))
                  (unless exception?
                    (setf result (sbhl-gather-first-sd-or-store-sd-candidates c2))
                    (unless result
                      (setf result (sbhl-determine-sd-path-with-no-exceptions c1)))))
                (free-sbhl-marking-space *sd-candidate-store*)))
            (free-sbhl-marking-space *sd-genls-isas-space*))
          (free-sbhl-marking-space *sd-c2-genls-space*))
        (free-sbhl-marking-space *sd-c1-genls-space*))))
    result)

(defun any-isa-common-sdct-among (c1s c2 &optional mt tv)
  "[Cyc] Returns the first common sibling-disjoint collection type for any of C1S and C2."
  (let ((result nil)
        (result2 nil)
        (exception? nil))
    (let ((*mt* (update-inference-mt-relevance-mt mt))
          (*relevant-mt-function* (update-inference-mt-relevance-function mt))
          (*relevant-mts* (update-inference-mt-relevance-mt-list mt)))
      (let ((*sbhl-tv* (if tv tv (get-sbhl-true-tv)))
            (*relevant-sbhl-tv-function* (if tv
                                             'relevant-sbhl-tv-is-general-tv
                                             *relevant-sbhl-tv-function*)))
        (when tv
          (when (sbhl-object-type-checking-p)
            (unless (sbhl-true-tv-p tv)
              (let ((pcase-var *sbhl-type-error-action*))
                (cond
                  ((eql pcase-var :error)
                   (sbhl-error 1 "~A is not a ~A" tv 'sbhl-true-tv-p))
                  ((eql pcase-var :cerror)
                   ;; missing-larkc 2230 likely calls sbhl-cerror for type check
                   (missing-larkc 2230))
                  ((eql pcase-var :warn)
                   (warn "~A is not a ~A" tv 'sbhl-true-tv-p))
                  (t
                   (warn "~A is not a valid *sbhl-type-error-action* value"
                         *sbhl-type-error-action*)
                   (cerror "continue anyway"
                           "~A is not a ~A" tv 'sbhl-true-tv-p)))))))
        (let ((*sd-c1-genls-space* (get-sbhl-marking-space)))
          (let ((*sd-c2-genls-space* (get-sbhl-marking-space)))
            (let ((*sd-genls-isas-space* (get-sbhl-marking-space)))
              (let ((*sd-candidate-store* (get-sbhl-marking-space)))
                (setf c1s (sbhl-mark-sd-c1s-genls-and-non-c2-genls-isas c1s c2))
                (unless c1s
                  (setf exception? t))
                (unless exception?
                  (when *sdc-exception-transfers-thru-specs?*
                    (let* ((module (get-sbhl-module #$genls))
                           (*sbhl-search-module* module)
                           (*sbhl-search-module-type* (get-sbhl-module-type module))
                           (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
                           (*genl-inverse-mode-p* nil)
                           (*sbhl-module* module)
                           (*sbhl-search-behavior* (determine-sbhl-search-behavior
                                                    (get-sbhl-search-module)
                                                    (get-sbhl-search-direction)
                                                    (get-sbhl-tv)))
                           (*sbhl-terminating-marking-space* (determine-sbhl-terminating-marking-space
                                                              *sbhl-search-behavior*)))
                      (unless exception?
                        (catch :do-hash-table
                          (maphash (lambda (c2-genl val)
                                     (declare (ignore val))
                                     ;; missing-larkc 4757, likely checks c2-genl relevance
                                     (missing-larkc 4757)
                                     (let ((exceptions (direct-sdc-exceptions c2-genl)))
                                       (unless exception?
                                         (dolist (exception exceptions)
                                           (when exception?
                                             (return))
                                           (when (sbhl-search-path-termination-p exception *sd-c1-genls-space*)
                                             (setf exception? t))))))
                                   *sd-c2-genls-space*)))))
                  (unless exception?
                    (setf result (sbhl-gather-first-sd-or-store-sd-candidates c2))
                    (unless result
                      (multiple-value-setq (result result2)
                        (sbhl-determine-sd-path-with-no-exceptions-among c1s)))))
                (free-sbhl-marking-space *sd-candidate-store*)))
            (free-sbhl-marking-space *sd-genls-isas-space*))
          (free-sbhl-marking-space *sd-c2-genls-space*))
        (free-sbhl-marking-space *sd-c1-genls-space*))))
    (values result result2))

(defun sbhl-mark-sd-c1-genls-and-non-c2-genls-isas (c1 c2)
  "[Cyc] in *sd-c1-genls-space* mark the genls of C1
   in *sd-genls-isas-space* mark the isas of those C1 genls that is not also C2 genls"
  (sbhl-mark-forward-true-nodes-in-space (get-sbhl-module #$genls) c2 *sd-c2-genls-space*)
  (let ((*sbhl-gather-space* (get-sbhl-marking-space)))
    (sbhl-map-and-mark-forward-true-nodes-in-space (get-sbhl-module #$genls) c1 'sbhl-mark-sd-genls-isas *sd-c1-genls-space*)
    (free-sbhl-marking-space *sbhl-gather-space*))
  nil)

(defun sbhl-mark-sd-c1s-genls-and-non-c2-genls-isas (c1s c2)
  "[Cyc] in *sd-c1-genls-space* mark the genls of C1S
   in *sd-genls-isas-space* mark the isas of those C1S genls that is not also C2 genls
   @return a list of the c1s used to mark the space."
  (sbhl-mark-forward-true-nodes-in-space (get-sbhl-module #$genls) c2 *sd-c2-genls-space*)
  (let ((new-c1s nil))
    (let* ((module (get-sbhl-module #$genls))
           (*sbhl-search-module* module)
           (*sbhl-search-module-type* (get-sbhl-module-type module))
           (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
           (*genl-inverse-mode-p* nil)
           (*sbhl-module* module)
           (*sbhl-search-behavior* (determine-sbhl-search-behavior
                                    (get-sbhl-search-module)
                                    (get-sbhl-search-direction)
                                    (get-sbhl-tv)))
           (*sbhl-terminating-marking-space* (determine-sbhl-terminating-marking-space
                                              *sbhl-search-behavior*))
           (*sbhl-gather-space* (get-sbhl-marking-space)))
      (dolist (c1 c1s)
        (unless (or (sbhl-search-path-termination-p c1 *sd-c2-genls-space*)
                    (genl? c1 c2))
          (sbhl-map-and-mark-forward-true-nodes-in-space (get-sbhl-module #$genls) c1 'sbhl-mark-sd-genls-isas *sd-c1-genls-space*)
          (push c1 new-c1s)))
      (free-sbhl-marking-space *sbhl-gather-space*))
    new-c1s))

(defun sbhl-mark-sd-genls-isas (c1-genl)
  "[Cyc] marks the all-isas of C1-GENL in *sd-genls-isas-space* (unless its also a genl of c2)"
  (unless (sbhl-search-path-termination-p c1-genl *sd-c2-genls-space*)
    (sbhl-mark-forward-true-nodes-in-space (get-sbhl-module #$isa) c1-genl *sd-genls-isas-space*))
  nil)

(defun sbhl-gather-first-sd-or-store-sd-candidates (c2)
  "[Cyc] returns the first node, GOAL, from the isas of the genls of C2
   s.t. (genls C2 C2-GENL) and (isa C2-GENL GOAL) and (isa GOAL SiblingDisjointCollectionType)
   s.t. C2-GENL is not in *sd-c1-genls-space* and GOAL is in *sd-genls-isas-space* and
   s.t. there are not sdw-exceptions relevant to GOAL defined as follows:
   if there are any X in *sd-c1-genls-space* s.t. (siblingDisjointExceptions C2-GENL X),
   we store these relevant exceptions as values keyed on GOAL instead of returning GOAL."
  (let ((result nil)
        (relevant-exceptions nil))
    (dolist (exception (sdc-exceptions c2))
      ;; missing-larkc 2081, likely tests if exception is in *sd-c1-genls-space*
      (when (missing-larkc 2081)
        (push exception relevant-exceptions)))
    (setf result (sbhl-gather-first-among-all-forward-true-nodes
                  (get-sbhl-module #$genls) c2 'sbhl-gather-sd-candidates))
    (when relevant-exceptions
      (if (hash-table-empty-p *sd-candidate-store*)
          (push-hash result relevant-exceptions *sd-candidate-store*)
          (catch :do-hash-table
            (maphash (lambda (c2-genl-isa exception-lists)
                       (let ((new-exceptions nil))
                         (dolist (exceptions exception-lists)
                           (push (nunion exceptions relevant-exceptions) new-exceptions))
                         (setf (gethash c2-genl-isa *sd-candidate-store*) new-exceptions)))
                     *sd-candidate-store*)))
      (return-from sbhl-gather-first-sd-or-store-sd-candidates nil))
    result))

(defparameter *sd-c2-genl* nil
  "[Cyc] the c2 genl currently considered during sbhl-gather-sd-candidates search")

(defun sbhl-gather-sd-candidates (c2-genl)
  "[Cyc] Implements first part of @see sbhl-gather-first-sd-or-store-sd-candidates.
   Gathers first sufficient isa of C2-GENL, or passes along information sufficient
   to determine relevant exceptions for candidate SD nodes."
  (let ((result nil))
    (unless (sbhl-search-path-termination-p c2-genl *sd-c1-genls-space*)
      (let ((*sd-c2-genl* c2-genl))
        (setf result (sbhl-gather-first-among-all-forward-true-nodes
                      (get-sbhl-module #$isa) c2-genl 'sbhl-determine-sd-and-store-candidates)))
      (return-from sbhl-gather-sd-candidates result))
    nil))

(defun sbhl-determine-sd-and-store-candidates (c2-genl-isa)
  "[Cyc] Implements second part of @see sbhl-gather-first-sd-or-store-sd-candidates.
   Determines sufficiency of C2-GENL-ISA, returns it if is in *sd-genls-isas-space*,
   isa #$SiblingDisjointCollectionType, and has no relevant exceptions.
   If C2-GENL-ISA only fails due to exceptions, saves C2-GENL-ISA as candidate along
   with relevant exceptions: saves this information as key, (list of values) in *sd-candidate-store*."
  (when (sbhl-sd-relevant-c2-genl-isa-candidate? c2-genl-isa)
    ;; missing-larkc 12568, likely sbhl-determine-sd-and-store-relevant-candidates
    (return-from sbhl-determine-sd-and-store-candidates (missing-larkc 12568)))
  nil)

;; clear-cached-sbhl-sd-relevant-c2-genl-isa-candidate? - commented-out declareFunction, (0 0) no body
;; remove-cached-sbhl-sd-relevant-c2-genl-isa-candidate? - commented-out declareFunction, (1 0) no body
;; cached-sbhl-sd-relevant-c2-genl-isa-candidate?-internal - commented-out declareFunction, (1 0) no body
;; cached-sbhl-sd-relevant-c2-genl-isa-candidate? - commented-out declareFunction, (1 0) no body

(deflexical *cached-sbhl-sd-relevant-c2-genl-isa-candidate?-caching-state* nil)

(defun sbhl-sd-relevant-c2-genl-isa-candidate? (c2-genl-isa)
  "[Cyc] Tests whether C2-GENL-ISA is in *sd-genls-isas-space* and is a sibling-disjoint collection."
  (and (sbhl-search-path-termination-p c2-genl-isa *sd-genls-isas-space*)
       (sibling-disjoint-collection-p c2-genl-isa)))

;; sbhl-determine-sd-and-store-relevant-candidates - commented-out declareFunction, (1 0) no body

(defun sbhl-determine-sd-path-with-no-exceptions (c1)
  "[Cyc] determines if there is any genls along isa path from c1 to a candidate c1-genl-isa
   that does not go through a set of relevant exceptions, stored in @see *sd-candidate-store*"
  (let ((result nil))
    (unless result
      (catch :do-hash-table
        (maphash (lambda (c1-genl-isa relevant-exceptions)
                   ;; missing-larkc 4758, likely checks isa-path relevance
                   (missing-larkc 4758)
                   (unless result
                     (dolist (c2-genl-exceptions relevant-exceptions)
                       (when result
                         (return))
                       ;; missing-larkc 12560, likely tests if exceptions block path
                       (when (missing-larkc 12560)
                         (setf result c1-genl-isa)))))
                 *sd-candidate-store*)))
    result))

(defun sbhl-determine-sd-path-with-no-exceptions-among (c1s)
  "[Cyc] determines if there is any genls along isa path from some c1 to a candidate c1-genl-isa
   that does not go through a set of relevant exceptions, stored in @see *sd-candidate-store*"
  (let ((result nil)
        (result2 nil))
    (unless result
      (dolist (c1 c1s)
        (when result
          (return))
        (unless result
          (catch :do-hash-table
            (maphash (lambda (c1-genl-isa relevant-exceptions)
                       ;; missing-larkc 4759, likely checks isa-path relevance
                       (missing-larkc 4759)
                       (dolist (c2-genl-exceptions relevant-exceptions)
                         ;; missing-larkc 12561, likely tests if exceptions block path
                         (when (missing-larkc 12561)
                           (setf result c1-genl-isa)
                           (push c1 result2))))
                     *sd-candidate-store*)))))
    (values result result2)))

;; any-sd-isa-path-excluding-exceptions-p - commented-out declareFunction, (3 0) no body
;; sbhl-sd-genls-and-genls-isa-path-p - commented-out declareFunction, (2 0) no body
;; sbhl-sd-goal-in-genls-isas-p - commented-out declareFunction, (1 0) no body

(defparameter *sbhl-sd-genls-isas-goal* nil
  "[Cyc] goal during sbhl-sd-genls-and-genls-isa-path-p search")

;; sdc - commented-out declareFunction, (1 1) no body
;; max-sdc - commented-out declareFunction, (1 1) no body
;; all-sdc - commented-out declareFunction, (1 1) no body
;; max-sdc-int - commented-out declareFunction, (1 0) no body
;; all-sdc-int - commented-out declareFunction, (1 0) no body
;; remote-sdc-wrt - commented-out declareFunction, (2 1) no body
;; isa-sdct - commented-out declareFunction, (1 1) no body
;; max-isa-sdct - commented-out declareFunction, (1 1) no body
;; applicable-sdct - commented-out declareFunction, (1 1) no body
;; gather-sdct-isas - commented-out declareFunction, (1 0) no body
;; gather-if-sdct? - commented-out declareFunction, (1 0) no body
;; all-isa-sdct - commented-out declareFunction, (1 1) no body

(deflexical *cached-all-isa-sdct-caching-state* nil)

(defun clear-cached-all-isa-sdct ()
  "[Cyc] Clears the caching state for cached-all-isa-sdct."
  (let ((cs *cached-all-isa-sdct-caching-state*))
    (when cs
      (caching-state-clear cs)))
  nil)

;; remove-cached-all-isa-sdct - commented-out declareFunction, (2 0) no body
;; cached-all-isa-sdct-internal - commented-out declareFunction, (2 0) no body
;; cached-all-isa-sdct - commented-out declareFunction, (2 0) no body
;; union-all-isa-sdct - commented-out declareFunction, (1 1) no body
;; sdc-element? - commented-out declareFunction, (1 1) no body
;; sdct-element? - commented-out declareFunction, (1 1) no body
;; safe-sdct-element? - commented-out declareFunction, (1 1) no body
;; applicable-sdct? - commented-out declareFunction, (1 1) no body

(defun sdc? (c1 c2 &optional mt)
  "[Cyc] is <c1> sibling-disjoint wrt <c2>?"
  (cond
    ((ground-naut? c1)
     ;; missing-larkc 10359, likely nart-substitute or find-nart
     (sdc? (missing-larkc 10359) c2 mt))
    ((ground-naut? c2)
     ;; missing-larkc 10360, likely nart-substitute or find-nart
     (sdc? c1 (missing-larkc 10360) mt))
    ((not (collection? c1))
     nil)
    ((not (collection? c2))
     nil)
    (t
     (let ((sdc? nil))
       (let ((*mt* (update-inference-mt-relevance-mt mt))
             (*relevant-mt-function* (update-inference-mt-relevance-function mt))
             (*relevant-mts* (update-inference-mt-relevance-mt-list mt)))
         (setf sdc? (sdc-int? c1 c2)))
       sdc?))))

(defun sdc-int? (c1 c2)
  "[Cyc] is <c1> sibling-disjoint with <c2> within <mt>?"
  (cond
    (*ignoring-sdc?*
     nil)
    ((not (isa-common-sdct? c1 c2))
     nil)
    ((establishing-superset? c1 c2)
     nil)
    ((establishing-superset? c2 c1)
     nil)
    ((establishing-instance-of? c1 c2)
     nil)
    (t t)))

(defun any-sdc-wrt? (c1s c2 &optional mt)
  "[Cyc] is any c1 in <c1s> sibling-disjoint with <c2> within <mt>?"
  (when (and c1s
             (collection? c2)
             (not *ignoring-sdc?*))
    (multiple-value-bind (sdc? rel-c1)
        (any-isa-common-sdct-among c1s c2 mt)
      (declare (ignore rel-c1))
      (dolist (c1 c1s)
        (cond
          ((establishing-superset? c1 c2 mt)
           nil)
          ((establishing-superset? c2 c1 mt)
           nil)
          ((establishing-instance-of? c1 c2 mt)
           (return-from any-sdc-wrt? nil))))
      (and sdc? t))))

;; any-sdc-wrt - commented-out declareFunction, (2 1) no body
;; any-sdc-any? - commented-out declareFunction, (2 1) no body
;; any-sdc-any - commented-out declareFunction, (2 1) no body

(defun sdc-exceptions (collection &optional mt)
  "[Cyc] Returns the sdc exceptions for COLLECTION."
  (sdc-exceptions-int collection mt))

(defun sdc-exceptions-int (collection &optional mt)
  "[Cyc] Internal implementation for sdc-exceptions."
  (remove-duplicate-forts
   (nconc (direct-sdc-exceptions collection mt)
          (if *sdc-common-spec-exception?*
              ;; missing-larkc 12564, likely sdc-exceptions-of-genls
              (missing-larkc 12564)
              nil))))

(deflexical *cached-sdc-exceptions-caching-state* nil)

;; clear-cached-sdc-exceptions - commented-out declareFunction, (0 0) no body
;; remove-cached-sdc-exceptions - commented-out declareFunction, (1 0) no body
;; cached-sdc-exceptions-internal - commented-out declareFunction, (1 0) no body
;; cached-sdc-exceptions - commented-out declareFunction, (1 0) no body
;; declared-sdc-exceptions - commented-out declareFunction, (1 1) no body
;; sdc-exceptions-of-genls - commented-out declareFunction, (1 1) no body
;; gather-direct-sdc-exceptions - commented-out declareFunction, (1 0) no body

(defun direct-sdc-exceptions (collection &optional mt)
  "[Cyc] declared exceptions to the sibling-disjoint cols wrt <collection>"
  (nunion (pred-values-in-relevant-mts collection #$siblingDisjointExceptions mt 1 2)
          (pred-values-in-relevant-mts collection #$siblingDisjointExceptions mt 2 1)))

;; direct-sdc-exception? - commented-out declareFunction, (2 1) no body
;; collections-sharing-specs - commented-out declareFunction, (1 1) no body
;; sdc-exception? - commented-out declareFunction, (2 1) no body
;; declared-sdc-exception? - commented-out declareFunction, (2 1) no body
;; remote-sdc-exception? - commented-out declareFunction, (2 1) no body
;; any-remote-sdc-exception-pair - commented-out declareFunction, (2 1) no body
;; gather-any-genls-sdc-exception - commented-out declareFunction, (1 0) no body
;; gather-direct-sdc-exception - commented-out declareFunction, (1 0) no body
;; sdc-common-spec? - commented-out declareFunction, (2 1) no body
;; remote-sdc-common-spec? - commented-out declareFunction, (2 1) no body
;; sdct-elements - commented-out declareFunction, (1 1) no body
;; cols-with-applicable-sdct - commented-out declareFunction, (1 1) no body

(defun establishing-superset? (c1 c2 &optional mt (assertion *added-assertion*))
  "[Cyc] don't claim sibling-disjoint when stating that c1 has superset c2"
  (cond
    (assertion
     (let ((axiom (assertion-formula assertion))
           (truth (assertion-truth assertion))
           (assertion-mt (assertion-mt assertion)))
       (let ((a1 (second axiom))
             (a2 (third axiom)))
         (and (genls-lit? axiom)
              (eq truth :true)
              (relevant-mt? assertion-mt)
              (genl? c1 a1 mt)
              (genl? a2 c2 mt)))))
    ((and (within-wff?) (within-assert?))
     (let ((formula (wff-formula)))
       (and (genls-lit? formula)
            (not (el-negation-p formula))
            (fort-p (literal-arg1 formula))
            (fort-p (literal-arg2 formula))
            (genl? c1 (literal-arg1 formula))
            (genl? (literal-arg2 formula) c2))))
    (t nil)))

(defun establishing-instance-of? (c1 c2 &optional mt (assertion *added-assertion*))
  "[Cyc] don't claim sibling-disjoint when stating
   that a common spec of c1 and c2 has an instance
   (e.g., printer-copier)"
  (when assertion
    (let ((axiom (assertion-formula assertion))
          (truth (assertion-truth assertion))
          (assertion-mt (assertion-mt assertion)))
      (let ((a1 (second axiom))
            (a2 (third axiom)))
        (declare (ignore a1))
        (and (isa-lit? axiom)
             (eq truth :true)
             (relevant-mt? assertion-mt)
             (genl? a2 c1 mt)
             (genl? a2 c2 mt))))))

;; why-sdc? - commented-out declareFunction, (2 2) no body
;; assemble-sdc-just - commented-out declareFunction, (1 0) no body
;; any-just-of-sdc - commented-out declareFunction, (2 1) no body
;; any-just-of-isa-sdct - commented-out declareFunction, (2 1) no body
;; why-sdc-exception? - commented-out declareFunction, (2 1) no body
;; why-declared-sdc-exception? - commented-out declareFunction, (2 1) no body
;; why-direct-sdc-exception? - commented-out declareFunction, (2 1) no body
;; why-remote-sdc-exception? - commented-out declareFunction, (2 1) no body
;; why-sdc-common-spec? - commented-out declareFunction, (2 1) no body
;; why-remote-common-spec? - commented-out declareFunction, (2 1) no body

(defun isa-common-sdct? (c1 c2 &optional mt)
  "[Cyc] Tests if C1 and C2 have a common sibling-disjoint collection type."
  (and (any-isa-common-sdct c1 c2 mt) t))

;; isa-common-sdct-among? - commented-out declareFunction, (2 1) no body
;; sdw-error - commented-out declareFunction, (2 5) no body

;;; Additional variables

(defvar *sdw-trace-level* 1
  "[Cyc] current tracing level for sdw modules")

(defvar *sdw-test-level* 1
  "[Cyc] current testing level for sdw modules")

;;; Setup (toplevel forms)

(toplevel
  (note-globally-cached-function 'cached-sbhl-sd-relevant-c2-genl-isa-candidate?)
  (note-globally-cached-function 'cached-all-isa-sdct)
  (note-globally-cached-function 'cached-sdc-exceptions))
