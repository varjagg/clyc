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

;;; Variables from init section

(deflexical *at-check-quoted-arg-isa?* t)

(defvar *at-applicable-arg-types* nil
  "[Cyc] Storage for applicable applicable arg-types (e.g. argIsa argGenls)")

(defvar *at-applicable-arg-types-with-assertions* nil
  "[Cyc] Storage for the applicable arg-type (e.g. argIsa argGenls) with the KB assertions")

(defvar *ind-arg-relevant-constraints* nil)

;;; Macro: with-applicable-arg-types
;; Reconstructed from Internal Constants evidence:
;;   $sym0$CLET = CLET
;;   $list1 = (*AT-APPLICABLE-ARG-TYPES* (*AT-APPLICABLE-ARG-TYPES-WITH-ASSERTIONS* (NEW-DICTIONARY (QUOTE EQUAL))))
;;   $sym2$ALLOW_ESCAPE_QUOTE_WHEN_QUOTE_PREDICATE
;;   $sym3$RELN
;;   $sym4$WITH_SBHL_RESOURCED_MARKING_SPACES
;; The macro binds the two at-applicable-arg-types variables, then wraps the body
;; in allow-escape-quote-when-quote-predicate and with-sbhl-resourced-marking-spaces.
;; commented declareMacro

;; (defmacro with-applicable-arg-types ...) -- no body, commented declareMacro
;; Expansion would be:
;; (clet ((*at-applicable-arg-types* nil)
;;        (*at-applicable-arg-types-with-assertions* (new-dictionary #'equal)))
;;   (allow-escape-quote-when-quote-predicate reln
;;     (with-sbhl-resourced-marking-spaces
;;       . body)))

;;; Functions in declare section order

(defun mal-arg-isa? (reln arg argnum)
  "[Cyc] Do the arg-isa collections applicable to arg number ARGNUM of relation RELN include ARG?"
  (when *at-check-arg-isa?*
    (let ((result nil)
          (done? nil)
          (arg-isas-found? nil))
      (let ((*at-applicable-arg-types* nil)
            (*at-applicable-arg-types-with-assertions* (new-dictionary #'equal)))
        (if (eq reln #$Quote)
            (let ((*within-quote-form* t))
              (let ((already-resourcing-p *resourcing-sbhl-marking-spaces-p*))
                (let ((*resourced-sbhl-marking-space-limit* (determine-resource-limit already-resourcing-p 10))
                      (*resourced-sbhl-marking-spaces* (possibly-new-marking-resource already-resourcing-p))
                      (*resourcing-sbhl-marking-spaces-p* t))
                  (applicable-arg-type-collections reln argnum :arg-isa)
                  (when *at-applicable-arg-types*
                    (let ((fort-type-arg-isas (remove-if-not #'valid-fort-type? *at-applicable-arg-types*))
                          (other-arg-isas (remove-if #'valid-fort-type? *at-applicable-arg-types*)))
                      (setf arg-isas-found? t)
                      (unless done?
                        (dolist (col fort-type-arg-isas)
                          (when done? (return))
                          (let ((*wff-violations* nil)
                                (*permitting-denotational-terms-admitted-by-defn-via-isa?* nil))
                            (when (not (fort-has-type? arg col))
                              (when (not (defns-admit? col arg))
                                (when *noting-at-violations?*
                                  ;; missing-larkc 11260 likely calls note-at-violations with arg-isa-violations
                                  (missing-larkc 11260)
                                  ;; missing-larkc 11261 likely calls note-at-violations with wff-violations
                                  (missing-larkc 11261))
                                (setf result t)
                                (setf done? (at-finished? result)))))))
                      (unless done?
                        (dolist (col other-arg-isas)
                          (when done? (return))
                          (let ((*wff-violations* nil))
                            (when (not (has-type? arg col))
                              (when *noting-at-violations?*
                                ;; missing-larkc 11262 likely calls note-at-violations with arg-isa-violations
                                (missing-larkc 11262)
                                ;; missing-larkc 11263 likely calls note-at-violations with wff-violations
                                (missing-larkc 11263))
                              (setf result t)
                              (setf done? (at-finished? result)))))))))))
            ;; Non-Quote branch
            (let ((already-resourcing-p *resourcing-sbhl-marking-spaces-p*))
              (let ((*resourced-sbhl-marking-space-limit* (determine-resource-limit already-resourcing-p 10))
                    (*resourced-sbhl-marking-spaces* (possibly-new-marking-resource already-resourcing-p))
                    (*resourcing-sbhl-marking-spaces-p* t))
                (applicable-arg-type-collections reln argnum :arg-isa)
                (when *at-applicable-arg-types*
                  (let ((fort-type-arg-isas (remove-if-not #'valid-fort-type? *at-applicable-arg-types*))
                        (other-arg-isas (remove-if #'valid-fort-type? *at-applicable-arg-types*)))
                    (setf arg-isas-found? t)
                    (unless done?
                      (dolist (col fort-type-arg-isas)
                        (when done? (return))
                        (let ((*wff-violations* nil)
                              (*permitting-denotational-terms-admitted-by-defn-via-isa?* nil))
                          (when (not (fort-has-type? arg col))
                            (when (not (defns-admit? col arg))
                              (when *noting-at-violations?*
                                (note-at-violations (arg-isa-violations reln arg argnum col))
                                (note-at-violations (wff-violations)))
                              (setf result t)
                              (setf done? (at-finished? result)))))))
                    (unless done?
                      (dolist (col other-arg-isas)
                        (when done? (return))
                        (let ((*wff-violations* nil))
                          (when (not (has-type? arg col))
                            (when *noting-at-violations?*
                              (note-at-violations (arg-isa-violations reln arg argnum col))
                              (note-at-violations (wff-violations)))
                            (setf result t)
                            (setf done? (at-finished? result))))))))))))
      (when (and (at-some-arg-isa-required?)
                 (not done?))
        (if arg-isas-found?
            (setf result nil)
            (progn
              ;; missing-larkc 7213 likely constructs an arg-isa-required violation
              (missing-larkc 7213)
              (setf result t))))
      result)))

;; (defun arg-isa-violations (reln arg argnum col) ...) -- no body, commented declareFunction
;; Body present in Java, ported for reference:
(defun arg-isa-violations (reln arg argnum col)
  "[Cyc] Returns violations for arg-isa constraint COL on ARG at ARGNUM of RELN."
  (let ((constraints (gethash col *at-applicable-arg-types-with-assertions*))
        (violations nil))
    (dolist (constraint-details constraints)
      (push (arg-isa-violation reln arg argnum col constraint-details) violations))
    violations))

;; (defun arg-isa-violation (reln arg argnum col constraint-details) ...) -- no body, commented declareFunction
;; Body present in Java, ported for reference:
(defun arg-isa-violation (reln arg argnum col constraint-details)
  "[Cyc] Construct a single arg-isa violation."
  (let ((mt *mt*)
        (module (if (admitting-defns? col mt)
                    :mal-arg-wrt-col-defn
                    :mal-arg-wrt-arg-isa)))
    (arg-isa-violation-int reln arg argnum col constraint-details module)))

;; (defun arg-isa-violation-int (reln arg argnum col constraint-details module) ...) -- no body, commented declareFunction
;; Body present in Java, ported for reference:
(defun arg-isa-violation-int (reln arg argnum col constraint-details module)
  "[Cyc] Internal function to construct an arg-isa violation structure."
  (let ((mt *mt*)
        (data nil))
    (destructuring-bind (constraint-reln via constraint-gaf) constraint-details
      (unless (eq via :self)
        (push (list via constraint-reln) data))
      (unless (wff-violation-data-terse?)
        (when (and *include-at-constraint-gaf?* constraint-gaf)
          (push (list :at-constraint-gaf constraint-gaf) data))
        (setf data (append data (wff-violation-verbose-data))))
      (list* module arg reln argnum col mt (append data nil)))))

;; (defun wff-violation-verbose-data () ...) -- no body, commented declareFunction
;; Body present in Java, ported for reference:
(defun wff-violation-verbose-data ()
  "[Cyc] Collect verbose data about the current WFF context."
  (let ((data nil))
    (when (wff-formula)
      (push (list :wff-formula (wff-formula)) data))
    (when (wff-expansion-formula)
      (push (list :wff-expansion-formula (wff-expansion-formula)) data))
    (when (wff-original-formula)
      (push (list :wff-original-formula (wff-original-formula)) data))
    data))

;; (defun arg-isa-required-violation (reln argnum &optional mt) ...) -- no body, commented declareFunction

(defun mal-arg-not-isa-disjoint? (reln arg argnum)
  "[Cyc] Are any arg-isa collections applicable to arg number ARGNUM of relation RELN known to not include ARG?"
  (when *at-check-not-isa-disjoint?*
    (let ((result nil)
          (done? nil))
      (let ((*at-applicable-arg-types* nil)
            (*at-applicable-arg-types-with-assertions* (new-dictionary #'equal)))
        (if (eq reln #$Quote)
            (let ((*within-quote-form* t))
              (let ((already-resourcing-p *resourcing-sbhl-marking-spaces-p*))
                (let ((*resourced-sbhl-marking-space-limit* (determine-resource-limit already-resourcing-p 10))
                      (*resourced-sbhl-marking-spaces* (possibly-new-marking-resource already-resourcing-p))
                      (*resourcing-sbhl-marking-spaces-p* t))
                  (applicable-arg-type-collections reln argnum :arg-isa)
                  (when *at-applicable-arg-types*
                    (let ((isa-collections (arg-collections arg :isa *at-arg-type* (mt-info))))
                      (let ((*ignoring-sdc?* (not *at-check-not-sdc?*)))
                        (unless done?
                          (dolist (arg-isa *at-applicable-arg-types*)
                            (when done? (return))
                            (let ((*wff-violations* nil))
                              (cond
                                ((not (fort-p arg-isa)))
                                ((any-disjoint-with? isa-collections arg-isa)
                                 (when *noting-at-violations?*
                                   ;; missing-larkc 11268 likely notes arg-not-isa-disjoint violations
                                   (missing-larkc 11268))
                                 (setf result t)
                                 (setf done? (at-finished? result)))
                                ((and (eq :naut *at-arg-type*)
                                      (formula-find-if #'variable-term-wrt-arg-type? arg)))
                                ((defns-reject? arg-isa arg)
                                 (when *noting-at-violations?*
                                   ;; missing-larkc 11269 likely notes defn-reject violations
                                   (missing-larkc 11269)
                                   ;; missing-larkc 11270 likely notes wff-violations
                                   (missing-larkc 11270))
                                 (setf result t)
                                 (setf done? (at-finished? result)))))))))))))
            ;; Non-Quote branch
            (let ((already-resourcing-p *resourcing-sbhl-marking-spaces-p*))
              (let ((*resourced-sbhl-marking-space-limit* (determine-resource-limit already-resourcing-p 10))
                    (*resourced-sbhl-marking-spaces* (possibly-new-marking-resource already-resourcing-p))
                    (*resourcing-sbhl-marking-spaces-p* t))
                (applicable-arg-type-collections reln argnum :arg-isa)
                (when *at-applicable-arg-types*
                  (let ((isa-collections (arg-collections arg :isa *at-arg-type* (mt-info))))
                    (let ((*ignoring-sdc?* (not *at-check-not-sdc?*)))
                      (unless done?
                        (dolist (arg-isa *at-applicable-arg-types*)
                          (when done? (return))
                          (let ((*wff-violations* nil))
                            (cond
                              ((not (fort-p arg-isa)))
                              ((any-disjoint-with? isa-collections arg-isa)
                               (when *noting-at-violations?*
                                 ;; missing-larkc 11271 likely notes arg-not-isa-disjoint violations
                                 (missing-larkc 11271))
                               (setf result t)
                               (setf done? (at-finished? result)))
                              ((and (eq :naut *at-arg-type*)
                                    (formula-find-if #'variable-term-wrt-arg-type? arg)))
                              ((defns-reject? arg-isa arg)
                               (when *noting-at-violations?*
                                 ;; missing-larkc 11272 likely notes defn-reject violations
                                 (missing-larkc 11272)
                                 ;; missing-larkc 11273 likely notes wff-violations
                                 (missing-larkc 11273))
                               (setf result t)
                               (setf done? (at-finished? result))))))))))))))
      result)))

;; (defun arg-not-isa-disjoint-violations (reln arg argnum col) ...) -- no body, commented declareFunction
;; (defun arg-not-isa-disjoint-violation-int (reln arg argnum col constraint-details module) ...) -- no body, commented declareFunction

(defun mal-arg-quoted-isa? (reln arg argnum)
  "[Cyc] Do the arg-quoted-isa collections applicable to arg number ARGNUM of relation RELN include ARG?"
  (when *at-check-arg-quoted-isa?*
    (let ((result nil)
          (done? nil))
      (let ((*at-applicable-arg-types* nil)
            (*at-applicable-arg-types-with-assertions* (new-dictionary #'equal)))
        (if (eq reln #$Quote)
            (let ((*within-quote-form* t))
              (let ((already-resourcing-p *resourcing-sbhl-marking-spaces-p*))
                (let ((*resourced-sbhl-marking-space-limit* (determine-resource-limit already-resourcing-p 10))
                      (*resourced-sbhl-marking-spaces* (possibly-new-marking-resource already-resourcing-p))
                      (*resourcing-sbhl-marking-spaces-p* t))
                  (applicable-arg-type-collections reln argnum :arg-quoted-isa)
                  (when *at-applicable-arg-types*
                    (unless done?
                      (dolist (col *at-applicable-arg-types*)
                        (when done? (return))
                        (let ((*wff-violations* nil))
                          (when (not (quoted-has-type? arg col))
                            (when *noting-at-violations?*
                              ;; missing-larkc 11274 likely notes arg-quoted-isa violations
                              (missing-larkc 11274)
                              ;; missing-larkc 11275 likely notes wff-violations
                              (missing-larkc 11275))
                            (setf result t)
                            (setf done? (at-finished? result))))))))))
            ;; Non-Quote branch
            (let ((already-resourcing-p *resourcing-sbhl-marking-spaces-p*))
              (let ((*resourced-sbhl-marking-space-limit* (determine-resource-limit already-resourcing-p 10))
                    (*resourced-sbhl-marking-spaces* (possibly-new-marking-resource already-resourcing-p))
                    (*resourcing-sbhl-marking-spaces-p* t))
                (applicable-arg-type-collections reln argnum :arg-quoted-isa)
                (when *at-applicable-arg-types*
                  (unless done?
                    (dolist (col *at-applicable-arg-types*)
                      (when done? (return))
                      (let ((*wff-violations* nil))
                        (when (not (quoted-has-type? arg col))
                          (when *noting-at-violations?*
                            ;; missing-larkc 11276 likely notes arg-quoted-isa violations
                            (missing-larkc 11276)
                            ;; missing-larkc 11277 likely notes wff-violations
                            (missing-larkc 11277))
                          (setf result t)
                          (setf done? (at-finished? result)))))))))))
      result)))

;; (defun arg-quoted-isa-violations (reln arg argnum col) ...) -- no body, commented declareFunction
;; (defun arg-quoted-isa-violation (reln arg argnum col constraint-details) ...) -- no body, commented declareFunction

(defun mal-arg-not-quoted-isa-disjoint? (reln arg argnum)
  "[Cyc] Are any arg-quoted-isa collections applicable to arg number ARGNUM of relation RELN known to not include ARG?"
  (when *at-check-not-quoted-isa-disjoint?*
    (let ((result nil)
          (done? nil))
      (let ((*at-applicable-arg-types* nil)
            (*at-applicable-arg-types-with-assertions* (new-dictionary #'equal)))
        (if (eq reln #$Quote)
            (let ((*within-quote-form* t))
              (let ((already-resourcing-p *resourcing-sbhl-marking-spaces-p*))
                (let ((*resourced-sbhl-marking-space-limit* (determine-resource-limit already-resourcing-p 10))
                      (*resourced-sbhl-marking-spaces* (possibly-new-marking-resource already-resourcing-p))
                      (*resourcing-sbhl-marking-spaces-p* t))
                  (applicable-arg-type-collections reln argnum :arg-quoted-isa)
                  (when *at-applicable-arg-types*
                    (let ((quoted-isa-collections (arg-collections arg :quoted-isa *at-arg-type* (mt-info))))
                      (let ((*ignoring-sdc?* (not *at-check-not-sdc?*)))
                        (unless done?
                          (dolist (arg-quoted-isa *at-applicable-arg-types*)
                            (when done? (return))
                            (let ((*wff-violations* nil))
                              (cond
                                ((not (fort-p arg-quoted-isa)))
                                ((and (eq reln #$termOfUnit)
                                      (eql argnum 2)
                                      (eq arg-quoted-isa #$CycLReifiableNonAtomicTerm)
                                      ;; missing-larkc 5368 likely checks if the arg is a valid reifiable NAT
                                      (missing-larkc 5368)))
                                ((any-disjoint-with? quoted-isa-collections arg-quoted-isa)
                                 (when *noting-at-violations?*
                                   ;; missing-larkc 11278 likely notes arg-not-quoted-isa-disjoint violations
                                   (missing-larkc 11278))
                                 (setf result t)
                                 (setf done? (at-finished? result)))
                                ((and (eq :naut *at-arg-type*)
                                      (formula-find-if #'variable-term-wrt-arg-type? arg)))
                                ;; missing-larkc 5427 likely calls quoted-defns-reject?
                                ((missing-larkc 5427)
                                 (when *noting-at-violations?*
                                   ;; missing-larkc 11279 likely notes quoted-defn-reject violations
                                   (missing-larkc 11279)
                                   ;; missing-larkc 11280 likely notes wff-violations
                                   (missing-larkc 11280))
                                 (setf result t)
                                 (setf done? (at-finished? result)))))))))))))
            ;; Non-Quote branch
            (let ((already-resourcing-p *resourcing-sbhl-marking-spaces-p*))
              (let ((*resourced-sbhl-marking-space-limit* (determine-resource-limit already-resourcing-p 10))
                    (*resourced-sbhl-marking-spaces* (possibly-new-marking-resource already-resourcing-p))
                    (*resourcing-sbhl-marking-spaces-p* t))
                (applicable-arg-type-collections reln argnum :arg-quoted-isa)
                (when *at-applicable-arg-types*
                  (let ((quoted-isa-collections (arg-collections arg :quoted-isa *at-arg-type* (mt-info))))
                    (let ((*ignoring-sdc?* (not *at-check-not-sdc?*)))
                      (unless done?
                        (dolist (arg-quoted-isa *at-applicable-arg-types*)
                          (when done? (return))
                          (let ((*wff-violations* nil))
                            (cond
                              ((not (fort-p arg-quoted-isa)))
                              ((and (eq reln #$termOfUnit)
                                    (eql argnum 2)
                                    (eq arg-quoted-isa #$CycLReifiableNonAtomicTerm)
                                    ;; missing-larkc 5369 likely checks if the arg is a valid reifiable NAT
                                    (missing-larkc 5369)))
                              ((any-disjoint-with? quoted-isa-collections arg-quoted-isa)
                               (when *noting-at-violations?*
                                 ;; missing-larkc 11281 likely notes arg-not-quoted-isa-disjoint violations
                                 (missing-larkc 11281))
                               (setf result t)
                               (setf done? (at-finished? result)))
                              ((and (eq :naut *at-arg-type*)
                                    (formula-find-if #'variable-term-wrt-arg-type? arg)))
                              ;; missing-larkc 5428 likely calls quoted-defns-reject?
                              ((missing-larkc 5428)
                               (when *noting-at-violations?*
                                 ;; missing-larkc 11282 likely notes quoted-defn-reject violations
                                 (missing-larkc 11282)
                                 ;; missing-larkc 11283 likely notes wff-violations
                                 (missing-larkc 11283))
                               (setf result t)
                               (setf done? (at-finished? result))))))))))))))
      result)))

;; (defun arg-not-quoted-isa-disjoint-violations (reln arg argnum col) ...) -- no body, commented declareFunction

(defun mal-arg-genls? (reln arg argnum)
  "[Cyc] Do the arg-genl collections applicable to arg number ARGNUM of relation RELN include ARG?"
  (let ((result nil)
        (done? nil))
    (let ((*at-applicable-arg-types* nil)
          (*at-applicable-arg-types-with-assertions* (new-dictionary #'equal)))
      (if (eq reln #$Quote)
          (let ((*within-quote-form* t))
            (let ((already-resourcing-p *resourcing-sbhl-marking-spaces-p*))
              (let ((*resourced-sbhl-marking-space-limit* (determine-resource-limit already-resourcing-p 10))
                    (*resourced-sbhl-marking-spaces* (possibly-new-marking-resource already-resourcing-p))
                    (*resourcing-sbhl-marking-spaces-p* t))
                (applicable-arg-type-collections reln argnum :arg-genls)
                (if *at-applicable-arg-types*
                    (progn
                      (when (collection-p arg)
                        (setf *at-applicable-arg-types* (remove #$Thing *at-applicable-arg-types*)))
                      (unless done?
                        (dolist (col *at-applicable-arg-types*)
                          (when done? (return))
                          (when (and (fort-p col)
                                     (at-denotational-term-p arg))
                            (when (not (genl? arg col))
                              (when *noting-at-violations?*
                                ;; missing-larkc 11284 likely notes arg-genl violations
                                (missing-larkc 11284))
                              (setf result t)
                              (setf done? (at-finished? result)))))))
                    (setf result nil)))))
          ;; Non-Quote branch
          (let ((already-resourcing-p *resourcing-sbhl-marking-spaces-p*))
            (let ((*resourced-sbhl-marking-space-limit* (determine-resource-limit already-resourcing-p 10))
                  (*resourced-sbhl-marking-spaces* (possibly-new-marking-resource already-resourcing-p))
                  (*resourcing-sbhl-marking-spaces-p* t))
              (applicable-arg-type-collections reln argnum :arg-genls)
              (if *at-applicable-arg-types*
                  (progn
                    (when (collection-p arg)
                      (setf *at-applicable-arg-types* (remove #$Thing *at-applicable-arg-types*)))
                    (unless done?
                      (dolist (col *at-applicable-arg-types*)
                        (when done? (return))
                        (when (and (fort-p col)
                                   (at-denotational-term-p arg))
                          (when (not (genl? arg col))
                            (when *noting-at-violations?*
                              (note-at-violations (arg-genl-violations reln arg argnum col)))
                            (setf result t)
                            (setf done? (at-finished? result)))))))
                  (setf result nil))))))
    result))

;; (defun arg-genl-violations (reln arg argnum col) ...) -- no body, commented declareFunction
;; Body present in Java, ported for reference:
(defun arg-genl-violations (reln arg argnum col)
  "[Cyc] Returns violations for arg-genl constraint COL on ARG at ARGNUM of RELN."
  (let ((constraints (gethash col *at-applicable-arg-types-with-assertions*))
        (violations nil))
    (dolist (constraint-details constraints)
      (push (arg-genl-violation reln arg argnum col constraint-details) violations))
    violations))

;; (defun arg-genl-violation (reln arg argnum col constraint-details) ...) -- no body, commented declareFunction
;; Body present in Java, ported for reference:
(defun arg-genl-violation (reln arg argnum col constraint-details)
  "[Cyc] Construct a single arg-genl violation."
  (let ((mt *mt*)
        (module :mal-arg-wrt-arg-genl)
        (data nil))
    (destructuring-bind (constraint-reln via constraint-gaf) constraint-details
      (unless (eq via :self)
        (push (list via constraint-reln) data))
      (unless (wff-violation-data-terse?)
        (when (and *include-at-constraint-gaf?* constraint-gaf)
          (push (list :at-constraint-gaf constraint-gaf) data))
        (setf data (append data (wff-violation-verbose-data))))
      (list* module arg reln argnum col mt (append data nil)))))

(defun mal-arg-not-genls-disjoint? (reln arg argnum)
  "[Cyc] Are any arg-isa collections applicable to arg number ARGNUM of relation RELN known to not include ARG?"
  (when *at-check-not-genls-disjoint?*
    (let ((result nil)
          (done? nil))
      (let ((*at-applicable-arg-types* nil)
            (*at-applicable-arg-types-with-assertions* (new-dictionary #'equal)))
        (if (eq reln #$Quote)
            (let ((*within-quote-form* t))
              (let ((already-resourcing-p *resourcing-sbhl-marking-spaces-p*))
                (let ((*resourced-sbhl-marking-space-limit* (determine-resource-limit already-resourcing-p 10))
                      (*resourced-sbhl-marking-spaces* (possibly-new-marking-resource already-resourcing-p))
                      (*resourcing-sbhl-marking-spaces-p* t))
                  (applicable-arg-type-collections reln argnum :arg-genls)
                  (when *at-applicable-arg-types*
                    (let ((genl-collections (arg-collections arg :genls *at-arg-type* (mt-info))))
                      (let ((*ignoring-sdc?* (not *at-check-not-sdc?*)))
                        (unless done?
                          (dolist (arg-genl *at-applicable-arg-types*)
                            (when done? (return))
                            (when (fort-p arg-genl)
                              (when (any-disjoint-with? genl-collections arg-genl)
                                (when *noting-at-violations?*
                                  ;; missing-larkc 11286 likely notes arg-not-genl-disjoint violations
                                  (missing-larkc 11286))
                                (setf result t)
                                (setf done? (at-finished? result))))))))))))
            ;; Non-Quote branch
            (let ((already-resourcing-p *resourcing-sbhl-marking-spaces-p*))
              (let ((*resourced-sbhl-marking-space-limit* (determine-resource-limit already-resourcing-p 10))
                    (*resourced-sbhl-marking-spaces* (possibly-new-marking-resource already-resourcing-p))
                    (*resourcing-sbhl-marking-spaces-p* t))
                (applicable-arg-type-collections reln argnum :arg-genls)
                (when *at-applicable-arg-types*
                  (let ((genl-collections (arg-collections arg :genls *at-arg-type* (mt-info))))
                    (let ((*ignoring-sdc?* (not *at-check-not-sdc?*)))
                      (unless done?
                        (dolist (arg-genl *at-applicable-arg-types*)
                          (when done? (return))
                          (when (fort-p arg-genl)
                            (when (any-disjoint-with? genl-collections arg-genl)
                              (when *noting-at-violations?*
                                ;; missing-larkc 11287 likely notes arg-not-genl-disjoint violations
                                (missing-larkc 11287))
                              (setf result t)
                              (setf done? (at-finished? result)))))))))))))
      result)))

;; (defun arg-not-genl-disjoint-violations (reln arg argnum col) ...) -- no body, commented declareFunction

(defun mal-arg-format? (reln arg argnum)
  "[Cyc] Check arg format constraints for ARGNUM of RELN against ARG."
  (when *at-check-arg-format?*
    (let ((result nil)
          (done? nil))
      (let ((*at-applicable-arg-types* nil)
            (*at-applicable-arg-types-with-assertions* (new-dictionary #'equal)))
        (if (eq reln #$Quote)
            (let ((*within-quote-form* t))
              (let ((already-resourcing-p *resourcing-sbhl-marking-spaces-p*))
                (let ((*resourced-sbhl-marking-space-limit* (determine-resource-limit already-resourcing-p 10))
                      (*resourced-sbhl-marking-spaces* (possibly-new-marking-resource already-resourcing-p))
                      (*resourcing-sbhl-marking-spaces-p* t))
                  (applicable-arg-type-collections reln argnum :format)
                  (when *at-applicable-arg-types*
                    (unless done?
                      (dolist (format *at-applicable-arg-types*)
                        (when done? (return))
                        (let ((*gather-at-format-violations?* t)
                              (*at-format-violations* nil))
                          (when (not (memoized-format-ok? format *at-formula* argnum *mt*))
                            (when *noting-at-violations?*
                              ;; missing-larkc 11288 likely notes arg-format violations
                              (missing-larkc 11288))
                            (setf result t)
                            (setf done? (at-finished? result))))))))))
            ;; Non-Quote branch
            (let ((already-resourcing-p *resourcing-sbhl-marking-spaces-p*))
              (let ((*resourced-sbhl-marking-space-limit* (determine-resource-limit already-resourcing-p 10))
                    (*resourced-sbhl-marking-spaces* (possibly-new-marking-resource already-resourcing-p))
                    (*resourcing-sbhl-marking-spaces-p* t))
                (applicable-arg-type-collections reln argnum :format)
                (when *at-applicable-arg-types*
                  (unless done?
                    (dolist (format *at-applicable-arg-types*)
                      (when done? (return))
                      (let ((*gather-at-format-violations?* t)
                            (*at-format-violations* nil))
                        (when (not (memoized-format-ok? format *at-formula* argnum *mt*))
                          (when *noting-at-violations?*
                            ;; missing-larkc 11289 likely notes arg-format violations
                            (missing-larkc 11289))
                          (setf result t)
                          (setf done? (at-finished? result)))))))))))
      result)))

;; (defun arg-format-violations (reln arg argnum format) ...) -- no body, commented declareFunction

(defun mal-inter-arg-isa? (reln ind-arg ind-argnum dep-arg dep-argnum)
  "[Cyc] The inter-arg-isa collections applicable to arg number ARGNUM of relation RELN that do not include ARG."
  (unless (and *at-check-inter-arg-isa?*
               reln ind-arg dep-arg
               (integerp ind-argnum))
    (return-from mal-inter-arg-isa? nil))
  (unless (or (not (inter-arg-isa-cache-initialized?))
              (some-inter-arg-isa-constraint-somewhere? reln))
    (return-from mal-inter-arg-isa? nil))
  (let ((result nil)
        (done? nil))
    (let ((*at-applicable-arg-types* nil)
          (*at-applicable-arg-types-with-assertions* (new-dictionary #'equal)))
      (if (eq reln #$Quote)
          (let ((*within-quote-form* t))
            (let ((already-resourcing-p *resourcing-sbhl-marking-spaces-p*))
              (let ((*resourced-sbhl-marking-space-limit* (determine-resource-limit already-resourcing-p 10))
                    (*resourced-sbhl-marking-spaces* (possibly-new-marking-resource already-resourcing-p))
                    (*resourcing-sbhl-marking-spaces-p* t))
                (applicable-inter-arg-type-collections reln ind-arg ind-argnum dep-argnum :inter-arg-isa *at-check-non-constant-inter-arg-isa?*)
                (when *at-applicable-arg-types*
                  (unless done?
                    (dolist (inter-arg-isas *at-applicable-arg-types*)
                      (when done? (return))
                      (let ((*wff-violations* nil)
                            (*permitting-denotational-terms-admitted-by-defn-via-isa?* nil))
                        (destructuring-bind (ind-arg-isa dep-arg-isa) inter-arg-isas
                          (declare (ignore ind-arg-isa))
                          (when (fort-p dep-arg-isa)
                            (cond
                              ((isa? dep-arg dep-arg-isa))
                              ((defns-admit? dep-arg-isa dep-arg))
                              (t
                               (when *noting-at-violations?*
                                 ;; missing-larkc 11290 likely notes inter-arg-isa violations
                                 (missing-larkc 11290)
                                 ;; missing-larkc 11291 likely notes wff-violations
                                 (missing-larkc 11291))
                               (setf result t)
                               (setf done? (at-finished? result)))))))))))))
          ;; Non-Quote branch
          (let ((already-resourcing-p *resourcing-sbhl-marking-spaces-p*))
            (let ((*resourced-sbhl-marking-space-limit* (determine-resource-limit already-resourcing-p 10))
                  (*resourced-sbhl-marking-spaces* (possibly-new-marking-resource already-resourcing-p))
                  (*resourcing-sbhl-marking-spaces-p* t))
              (applicable-inter-arg-type-collections reln ind-arg ind-argnum dep-argnum :inter-arg-isa *at-check-non-constant-inter-arg-isa?*)
              (when *at-applicable-arg-types*
                (unless done?
                  (dolist (inter-arg-isas *at-applicable-arg-types*)
                    (when done? (return))
                    (let ((*wff-violations* nil)
                          (*permitting-denotational-terms-admitted-by-defn-via-isa?* nil))
                      (destructuring-bind (ind-arg-isa dep-arg-isa) inter-arg-isas
                        (declare (ignore ind-arg-isa))
                        (when (fort-p dep-arg-isa)
                          (cond
                            ((isa? dep-arg dep-arg-isa))
                            ((defns-admit? dep-arg-isa dep-arg))
                            (t
                             (when *noting-at-violations?*
                               ;; missing-larkc 11292 likely notes inter-arg-isa violations
                               (missing-larkc 11292)
                               ;; missing-larkc 11293 likely notes wff-violations
                               (missing-larkc 11293))
                             (setf result t)
                             (setf done? (at-finished? result))))))))))))))
    result))

;; (defun inter-arg-isa-violations (reln ind-arg ind-argnum dep-arg dep-argnum ind-arg-isa dep-arg-isa) ...) -- no body, commented declareFunction
;; (defun inter-arg-violations (reln ind-arg ind-argnum dep-arg dep-argnum ind-arg-type dep-arg-type module) ...) -- no body, commented declareFunction

(defun mal-inter-arg-not-isa? (reln ind-arg ind-argnum dep-arg dep-argnum)
  "[Cyc] The inter-arg-not-isa collections applicable to arg number ARGNUM of relation RELN that do not include ARG."
  (unless (and *at-check-inter-arg-not-isa?*
               reln ind-arg dep-arg
               (integerp ind-argnum))
    (return-from mal-inter-arg-not-isa? nil))
  (unless (some-inter-arg-not-isa-constraint-somewhere? reln)
    (return-from mal-inter-arg-not-isa? nil))
  (let ((result nil)
        (done? nil))
    (let ((*at-applicable-arg-types* nil)
          (*at-applicable-arg-types-with-assertions* (new-dictionary #'equal)))
      (if (eq reln #$Quote)
          (let ((*within-quote-form* t))
            (let ((already-resourcing-p *resourcing-sbhl-marking-spaces-p*))
              (let ((*resourced-sbhl-marking-space-limit* (determine-resource-limit already-resourcing-p 10))
                    (*resourced-sbhl-marking-spaces* (possibly-new-marking-resource already-resourcing-p))
                    (*resourcing-sbhl-marking-spaces-p* t))
                (applicable-inter-arg-type-collections reln ind-arg ind-argnum dep-argnum :inter-arg-not-isa t)
                (when *at-applicable-arg-types*
                  (unless done?
                    (dolist (inter-arg-not-isas *at-applicable-arg-types*)
                      (when done? (return))
                      (let ((*wff-violations* nil)
                            (*permitting-denotational-terms-admitted-by-defn-via-isa?* nil))
                        (destructuring-bind (ind-arg-isa dep-arg-isa) inter-arg-not-isas
                          (declare (ignore ind-arg-isa))
                          (when (fort-p dep-arg-isa)
                            (let ((module nil))
                              (cond
                                ((isa? dep-arg dep-arg-isa)
                                 (setf module :mal-arg-wrt-inter-arg-not-isa)
                                 (setf result t)
                                 (setf done? (at-finished? result)))
                                ((defns-admit? dep-arg-isa dep-arg)
                                 (setf module :mal-arg-wrt-inter-arg-not-defn)
                                 (setf result t)
                                 (setf done? (at-finished? result))))
                              (when module
                                (when *noting-at-violations?*
                                  ;; missing-larkc 11294 likely notes inter-arg-not-isa violations
                                  (missing-larkc 11294)
                                  ;; missing-larkc 11295 likely notes wff-violations
                                  (missing-larkc 11295)))))))))))))
          ;; Non-Quote branch
          (let ((already-resourcing-p *resourcing-sbhl-marking-spaces-p*))
            (let ((*resourced-sbhl-marking-space-limit* (determine-resource-limit already-resourcing-p 10))
                  (*resourced-sbhl-marking-spaces* (possibly-new-marking-resource already-resourcing-p))
                  (*resourcing-sbhl-marking-spaces-p* t))
              (applicable-inter-arg-type-collections reln ind-arg ind-argnum dep-argnum :inter-arg-not-isa t)
              (when *at-applicable-arg-types*
                (unless done?
                  (dolist (inter-arg-not-isas *at-applicable-arg-types*)
                    (when done? (return))
                    (let ((*wff-violations* nil)
                          (*permitting-denotational-terms-admitted-by-defn-via-isa?* nil))
                      (destructuring-bind (ind-arg-isa dep-arg-isa) inter-arg-not-isas
                        (declare (ignore ind-arg-isa))
                        (when (fort-p dep-arg-isa)
                          (let ((module nil))
                            (cond
                              ((isa? dep-arg dep-arg-isa)
                               (setf module :mal-arg-wrt-inter-arg-not-isa)
                               (setf result t)
                               (setf done? (at-finished? result)))
                              ((defns-admit? dep-arg-isa dep-arg)
                               (setf module :mal-arg-wrt-inter-arg-not-defn)
                               (setf result t)
                               (setf done? (at-finished? result))))
                            (when module
                              (when *noting-at-violations?*
                                ;; missing-larkc 11296 likely notes inter-arg-not-isa violations
                                (missing-larkc 11296)
                                ;; missing-larkc 11297 likely notes wff-violations
                                (missing-larkc 11297))))))))))))))
    result))

(defun some-inter-arg-not-isa-constraint-somewhere? (reln)
  "[Cyc] Check if there is any inter-arg-not-isa constraint somewhere for RELN."
  (or (some-pred-assertion-somewhere? #$interArgNotIsa1-2 reln 1)
      (some-pred-assertion-somewhere? #$interArgNotIsa2-1 reln 1)))

;; (defun some-inter-arg-genl-assertion-somewhere? (reln) ...) -- no body, commented declareFunction
;; (defun some-inter-arg-genl-constraint-somewhere? (reln) ...) -- no body, commented declareFunction
;; (defun mal-inter-arg-genl? (reln ind-arg ind-argnum dep-arg dep-argnum) ...) -- no body, commented declareFunction
;; (defun inter-arg-genl-violations (reln ind-arg ind-argnum dep-arg dep-argnum ind-arg-genl dep-arg-genl) ...) -- no body, commented declareFunction

(defun mal-inter-arg-not-isa-disjoint? (reln ind-arg ind-argnum dep-arg dep-argnum)
  "[Cyc] The inter-arg-isa collections applicable to arg number ARGNUM of relation RELN that are known to not include ARG."
  (unless (and *at-check-inter-arg-isa?*
               *at-check-not-isa-disjoint?*
               ind-arg
               (integerp ind-argnum))
    (return-from mal-inter-arg-not-isa-disjoint? nil))
  (unless (or (not (inter-arg-isa-cache-initialized?))
              (some-inter-arg-isa-constraint-somewhere? reln))
    (return-from mal-inter-arg-not-isa-disjoint? nil))
  (let ((result nil)
        (done? nil))
    (let ((*at-applicable-arg-types* nil)
          (*at-applicable-arg-types-with-assertions* (new-dictionary #'equal)))
      (if (eq reln #$Quote)
          (let ((*within-quote-form* t))
            (let ((already-resourcing-p *resourcing-sbhl-marking-spaces-p*))
              (let ((*resourced-sbhl-marking-space-limit* (determine-resource-limit already-resourcing-p 10))
                    (*resourced-sbhl-marking-spaces* (possibly-new-marking-resource already-resourcing-p))
                    (*resourcing-sbhl-marking-spaces-p* t))
                (applicable-inter-arg-type-collections reln ind-arg ind-argnum dep-argnum :inter-arg-isa *at-check-non-constant-inter-arg-isa?*)
                (when *at-applicable-arg-types*
                  (unless done?
                    (dolist (inter-arg-isas *at-applicable-arg-types*)
                      (when done? (return))
                      (destructuring-bind (ind-arg-isa dep-arg-isa) inter-arg-isas
                        (declare (ignore ind-arg-isa))
                        (when (fort-p dep-arg-isa)
                          (let ((isa-collections (arg-collections dep-arg :isa *at-arg-type* (mt-info))))
                            (when (any-disjoint-with? isa-collections dep-arg-isa)
                              (when *noting-at-violations?*
                                ;; missing-larkc 11298 likely notes inter-arg-not-isa-disjoint violations
                                (missing-larkc 11298))
                              (setf result t)
                              (setf done? (at-finished? result))))
                          (let ((*wff-violations* nil))
                            (when (not done?)
                              (cond
                                ((and (eq :naut *at-arg-type*)
                                      (formula-find-if #'variable-term-wrt-arg-type? dep-arg)))
                                ((defns-reject? dep-arg-isa dep-arg)
                                 (when *noting-at-violations?*
                                   ;; missing-larkc 11299 likely notes defn-reject violations
                                   (missing-larkc 11299)
                                   ;; missing-larkc 11300 likely notes wff-violations
                                   (missing-larkc 11300))
                                 (setf result t)
                                 (setf done? (at-finished? result))))))))))))))
          ;; Non-Quote branch
          (let ((already-resourcing-p *resourcing-sbhl-marking-spaces-p*))
            (let ((*resourced-sbhl-marking-space-limit* (determine-resource-limit already-resourcing-p 10))
                  (*resourced-sbhl-marking-spaces* (possibly-new-marking-resource already-resourcing-p))
                  (*resourcing-sbhl-marking-spaces-p* t))
              (applicable-inter-arg-type-collections reln ind-arg ind-argnum dep-argnum :inter-arg-isa *at-check-non-constant-inter-arg-isa?*)
              (when *at-applicable-arg-types*
                (unless done?
                  (dolist (inter-arg-isas *at-applicable-arg-types*)
                    (when done? (return))
                    (destructuring-bind (ind-arg-isa dep-arg-isa) inter-arg-isas
                      (declare (ignore ind-arg-isa))
                      (when (fort-p dep-arg-isa)
                        (let ((isa-collections (arg-collections dep-arg :isa *at-arg-type* (mt-info))))
                          (when (any-disjoint-with? isa-collections dep-arg-isa)
                            (when *noting-at-violations?*
                              ;; missing-larkc 11301 likely notes inter-arg-not-isa-disjoint violations
                              (missing-larkc 11301))
                            (setf result t)
                            (setf done? (at-finished? result))))
                        (let ((*wff-violations* nil))
                          (when (not done?)
                            (cond
                              ((and (eq :naut *at-arg-type*)
                                    (formula-find-if #'variable-term-wrt-arg-type? dep-arg)))
                              ((defns-reject? dep-arg-isa dep-arg)
                               (when *noting-at-violations?*
                                 ;; missing-larkc 11302 likely notes defn-reject violations
                                 (missing-larkc 11302)
                                 ;; missing-larkc 11303 likely notes wff-violations
                                 (missing-larkc 11303))
                               (setf result t)
                               (setf done? (at-finished? result)))))))))))))
          ))
    result))

;; (defun inter-arg-not-isa-disjoint-violations (reln ind-arg ind-argnum dep-arg dep-argnum ind-arg-isa dep-arg-isa) ...) -- no body, commented declareFunction
;; (defun mal-inter-arg-not-genl-disjoint? (reln ind-arg ind-argnum dep-arg dep-argnum) ...) -- no body, commented declareFunction
;; (defun inter-arg-not-genl-disjoint-violations (reln ind-arg ind-argnum dep-arg dep-argnum ind-arg-genl dep-arg-genl) ...) -- no body, commented declareFunction

(defun mal-inter-arg-format? (reln ind-arg ind-argnum dep-arg dep-argnum)
  "[Cyc] The inter-arg-format collections applicable to arg number ARGNUM of relation RELN that do not include ARG."
  (declare (ignore dep-arg))
  (unless (and *at-check-inter-arg-format?*
               ind-arg
               (integerp ind-argnum))
    (return-from mal-inter-arg-format? nil))
  (unless (or (not (inter-arg-format-cache-initialized?))
              (some-inter-arg-format-constraint-somewhere? reln))
    (return-from mal-inter-arg-format? nil))
  (let ((result nil)
        (done? nil))
    (let ((*at-applicable-arg-types* nil)
          (*at-applicable-arg-types-with-assertions* (new-dictionary #'equal)))
      (if (eq reln #$Quote)
          (let ((*within-quote-form* t))
            (let ((already-resourcing-p *resourcing-sbhl-marking-spaces-p*))
              (let ((*resourced-sbhl-marking-space-limit* (determine-resource-limit already-resourcing-p 10))
                    (*resourced-sbhl-marking-spaces* (possibly-new-marking-resource already-resourcing-p))
                    (*resourcing-sbhl-marking-spaces-p* t))
                (applicable-inter-arg-type-collections reln ind-arg ind-argnum dep-argnum :inter-arg-format *at-check-non-constant-inter-arg-format?*)
                (when *at-applicable-arg-types*
                  (unless done?
                    (dolist (inter-arg-format *at-applicable-arg-types*)
                      (when done? (return))
                      (destructuring-bind (ind-arg-isa dep-arg-format) inter-arg-format
                        (declare (ignore ind-arg-isa))
                        (when (not (memoized-format-ok? dep-arg-format *at-formula* dep-argnum *mt*))
                          (when *noting-at-violations?*
                            ;; missing-larkc 11304 likely notes inter-arg-format violations
                            (missing-larkc 11304))
                          (setf result t)
                          (setf done? (at-finished? result))))))))))
          ;; Non-Quote branch
          (let ((already-resourcing-p *resourcing-sbhl-marking-spaces-p*))
            (let ((*resourced-sbhl-marking-space-limit* (determine-resource-limit already-resourcing-p 10))
                  (*resourced-sbhl-marking-spaces* (possibly-new-marking-resource already-resourcing-p))
                  (*resourcing-sbhl-marking-spaces-p* t))
              (applicable-inter-arg-type-collections reln ind-arg ind-argnum dep-argnum :inter-arg-format *at-check-non-constant-inter-arg-format?*)
              (when *at-applicable-arg-types*
                (unless done?
                  (dolist (inter-arg-format *at-applicable-arg-types*)
                    (when done? (return))
                    (destructuring-bind (ind-arg-isa dep-arg-format) inter-arg-format
                      (declare (ignore ind-arg-isa))
                      (when (not (memoized-format-ok? dep-arg-format *at-formula* dep-argnum *mt*))
                        (when *noting-at-violations?*
                          ;; missing-larkc 11305 likely notes inter-arg-format violations
                          (missing-larkc 11305))
                        (setf result t)
                        (setf done? (at-finished? result)))))))))))
    result))

;; (defun inter-arg-format-violations (reln ind-arg ind-argnum dep-arg dep-argnum ind-arg-isa dep-arg-format) ...) -- no body, commented declareFunction

(defun some-inter-arg-different-assertion-somewhere? (reln)
  "[Cyc] Check if there is any interArgDifferent assertion somewhere for RELN."
  (some-pred-assertion-somewhere? #$interArgDifferent reln 1))

(defun some-inter-arg-different-constraint-somewhere? (reln)
  "[Cyc] Check if there is any interArgDifferent constraint somewhere for RELN, via genl-preds."
  ;; Java body was a massive inline expansion of do-all-genl-preds + check.
  ;; Collapsed to iterate all-genl-predicates and check each.
  (let ((found-one? nil))
    (when (predicate? reln)
      (dolist (genl-pred (all-genl-predicates reln))
        (when found-one? (return))
        (when (some-inter-arg-different-assertion-somewhere? genl-pred)
          (setf found-one? t))))
    found-one?))

(defun inverse-pred (constraint-type argnum reln)
  "[Cyc] Return the inverse constraint predicate for the given constraint-type, argnum, and reln."
  (cond
    ((eql constraint-type :arg-isa)
     (arg-isa-inverse argnum reln *mt*))
    ((eql constraint-type :arg-quoted-isa)
     (arg-quoted-isa-inverse argnum reln *mt*))
    ((eql constraint-type :arg-genls)
     (arg-genl-inverse argnum reln *mt*))
    ((eql constraint-type :format)
     (argn-format-inverse argnum))
    (t
     (error "Unknown constraint-type ~s" constraint-type))))

(defun gather-ind-arg-relevant-constraints (ind-arg constraint-type)
  "[Cyc] Gather relevant constraints for the independent arg based on constraint-type."
  (cond
    ((eql constraint-type :inter-arg-isa)
     (setf *ind-arg-relevant-constraints* (all-isa ind-arg)))
    ((eql constraint-type :inter-arg-not-isa)
     (setf *ind-arg-relevant-constraints* (all-isa ind-arg)))
    ((eql constraint-type :inter-arg-genl)
     (setf *ind-arg-relevant-constraints* (all-genls ind-arg)))
    ((eql constraint-type :inter-arg-format)
     (setf *ind-arg-relevant-constraints* (all-isa ind-arg))))
  *ind-arg-relevant-constraints*)

(defun relevant-constraint? (ind-arg ind-arg-type ind-type constraint-type)
  "[Cyc] Check if ind-arg-type is relevant given the constraint-type."
  (when (eq constraint-type :inter-arg-different)
    (return-from relevant-constraint? t))
  (cond
    ((eql ind-type :fort)
     (member-eq? ind-arg-type *ind-arg-relevant-constraints*))
    ((eql ind-type :non-fort)
     (if (eql constraint-type :inter-arg-genl)
         (genl? ind-arg ind-arg-type)
         (quiet-has-type? ind-arg ind-arg-type)))))

(defun applicable-inter-arg-type-collections (reln ind-arg ind-argnum dep-argnum constraint-type check-non-constant?)
  "[Cyc] Gather applicable inter-arg-type collections for RELN."
  (let ((*ind-arg-relevant-constraints* nil))
    (cond
      ((fort-p ind-arg)
       (gather-ind-arg-relevant-constraints ind-arg constraint-type)
       (applicable-inter-arg-type-pred-collections reln ind-arg ind-argnum dep-argnum constraint-type :fort))
      ((variable-wrt-arg-type? ind-arg))
      (check-non-constant?
       (applicable-inter-arg-type-pred-collections reln ind-arg ind-argnum dep-argnum constraint-type :non-fort))))
  *at-applicable-arg-types*)

(defun applicable-inter-arg-type-pred-collections (reln ind-arg ind-argnum dep-argnum constraint-type &optional ind-type)
  "[Cyc] Gather applicable inter-arg-type pred collections for RELN."
  (let ((constraint-pred (inter-arg-constraint-pred constraint-type ind-argnum dep-argnum)))
    (unless (fort-p constraint-pred)
      (return-from applicable-inter-arg-type-pred-collections nil))
    (applicable-inter-arg-type-pred-collections-int constraint-pred reln ind-arg :self constraint-type ind-type)
    (when (fort-p reln)
      (let ((asserted-genl-preds-or-inverse? (or (asserted-genl-predicates? reln)
                                                  (asserted-genl-inverses? reln))))
        (when (and *at-check-genl-preds?* asserted-genl-preds-or-inverse?)
          (dolist (reln-genl-pred (all-genl-preds reln))
            (unless (eq reln-genl-pred reln)
              (applicable-inter-arg-type-pred-collections-int constraint-pred reln-genl-pred ind-arg :via-genl-pred constraint-type ind-type))))
        (when (and *at-check-genl-inverses?* asserted-genl-preds-or-inverse?)
          (let ((inverse-constraint-pred (inter-arg-inverse-pred constraint-type ind-argnum dep-argnum)))
            (dolist (inverse-reln (all-genl-inverses reln))
              (unless (eq inverse-reln reln)
                (applicable-inter-arg-type-pred-collections-int inverse-constraint-pred inverse-reln ind-arg :via-genl-inverse constraint-type ind-type))))))))
  *at-applicable-arg-types*)

(defun applicable-inter-arg-type-pred-collections-int (constraint-pred reln ind-arg via ind-type constraint-type)
  "[Cyc] Internal: gather applicable inter-arg-type collections from GAF index."
  (do-gaf-arg-index (assertion reln :index 1 :predicate constraint-pred)
    (let* ((ind-arg-type (gaf-arg2 assertion))
           (dep-arg-type (gaf-arg3 assertion))
           (inter-arg-type (list ind-arg-type dep-arg-type)))
      (when (relevant-constraint? ind-arg ind-arg-type constraint-type ind-type)
        (pushnew inter-arg-type *at-applicable-arg-types*)
        (when *noting-at-violations?*
          (dictionary-push *at-applicable-arg-types-with-assertions* inter-arg-type (list reln via))))))
  *at-applicable-arg-types*)

(defun inter-arg-constraint-pred (constraint-type ind-argnum dep-argnum)
  "[Cyc] Return the inter-arg constraint predicate for the given constraint-type."
  (cond
    ((eql constraint-type :inter-arg-isa)
     (inter-arg-isa-pred ind-argnum dep-argnum))
    ((eql constraint-type :inter-arg-not-isa)
     ;; missing-larkc 7195 likely calls inter-arg-not-isa-pred
     (missing-larkc 7195))
    ((eql constraint-type :inter-arg-genl)
     ;; missing-larkc 7192 likely calls inter-arg-genl-pred
     (missing-larkc 7192))
    ((eql constraint-type :inter-arg-format)
     (inter-arg-format-pred ind-argnum dep-argnum))
    ((eql constraint-type :inter-arg-different)
     #$interArgDifferent)))

(defun inter-arg-inverse-pred (constraint-type ind-arg dep-arg)
  "[Cyc] Return the inter-arg inverse constraint predicate for the given constraint-type."
  (cond
    ((eql constraint-type :inter-arg-isa)
     (inter-arg-isa-inverse ind-arg dep-arg))
    ((eql constraint-type :inter-arg-not-isa)
     ;; missing-larkc 7194 likely calls inter-arg-not-isa-inverse
     (missing-larkc 7194))
    ((eql constraint-type :inter-arg-genl)
     ;; missing-larkc 7191 likely calls inter-arg-genl-inverse
     (missing-larkc 7191))
    ((eql constraint-type :inter-arg-format)
     ;; missing-larkc 6878 likely calls inter-arg-format-inverse
     (missing-larkc 6878))
    ((eql constraint-type :inter-arg-different)
     nil)))

;; (defun note-at-violations (at-violations) ...) -- no body, commented declareFunction
;; Body present in Java, ported for reference:
(defun note-at-violations (at-violations)
  "[Cyc] Note each AT violation via at-utilities:note-at-violation."
  (dolist (at-violation at-violations)
    (note-at-violation at-violation))
  nil)

;;; Setup section

(toplevel
  (note-globally-cached-function 'arg-collections))
