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

;;; Functions ordered per declare_at_defns_file().

;; (defun suf-defn-cache-as-alist () ...) -- 0 required, 0 optional, no body
;; (defun suf-defn-cache-get (key) ...) -- 1 required, 0 optional, no body
;; (defun suf-defn-cache-add (key value) ...) -- 2 required, 0 optional, no body
;; (defun suf-defn-cache-rem (key value) ...) -- 2 required, 0 optional, no body
;; (defun suf-defn-cache-merge (key value) ...) -- 2 required, 0 optional, no body
;; (defun remove-suf-defn-assertions (arg1 &optional arg2) ...) -- 1 required, 1 optional, no body

(defun clear-suf-defns ()
  "[Cyc] Clear the sufficient defn cache."
  (clrhash *suf-defn-cache*)
  nil)

;; (defun sort-suf-defn-cache () ...) -- 0 required, 0 optional, no body
;; (defun suf-quoted-defn-cache-as-alist () ...) -- 0 required, 0 optional, no body
;; (defun suf-quoted-defn-cache-get (key) ...) -- 1 required, 0 optional, no body
;; (defun suf-quoted-defn-cache-add (key value) ...) -- 2 required, 0 optional, no body
;; (defun suf-quoted-defn-cache-rem (key value) ...) -- 2 required, 0 optional, no body
;; (defun suf-quoted-defn-cache-merge (key value) ...) -- 2 required, 0 optional, no body
;; (defun remove-suf-quoted-defn-assertions (arg1 &optional arg2) ...) -- 1 required, 1 optional, no body

(defun clear-suf-quoted-defns ()
  "[Cyc] Clear the sufficient quoted defn cache."
  (clrhash *suf-quoted-defn-cache*)
  nil)

;; (defun sort-suf-quoted-defn-cache () ...) -- 0 required, 0 optional, no body
;; (defun at-defns-admit? (arg1) ...) -- 1 required, 0 optional, no body
;; (defun at-defns-reject? (arg1) ...) -- 1 required, 0 optional, no body

(defun defns-admit? (collection v-term &optional (mt *mt*))
  "[Cyc] Return T iff the defns of COLLECTION admit V-TERM."
  (if *use-new-defns-functions?*
      (new-defns-admit? collection v-term mt)
      (missing-larkc 5340)))

;; In Java, only reset-old-defns-admit?-meters is active (metered/outer are commented).
;; Using define-defn-metered to get the reset function + setup-phase boilerplate;
;; the generated metered/outer functions are harmless extras.
(define-defn-metered old-defns-admit? (collection v-term mt)
  (missing-larkc "Generated metered/outer functions do not exist in Java; only the reset function is active."))

(defun defns-reject? (collection v-term &optional (mt *mt*))
  "[Cyc] Return T iff the defns of COLLECTION reject V-TERM."
  (if *use-new-defns-functions?*
      (new-defns-reject? collection v-term mt)
      (missing-larkc 5341)))

(define-defn-metered old-defns-reject? (collection v-term mt)
  (missing-larkc "Generated metered/outer functions do not exist in Java; only the reset function is active."))

;; (defun defining-defns-admit? (collection v-term &optional mt) ...) -- no body
;; (defun defining-defns-reject? (collection v-term &optional mt) ...) -- no body

(define-defn-metered defining-defns-status (collection v-term mt)
  (missing-larkc "Generated metered/outer functions do not exist in Java; only the reset function is active."))

;; (defun defining-defn-violation-data (arg1 arg2 arg3 arg4 &optional arg5) ...) -- no body

(define-defn-metered sufficient-defns-admit? (collection v-term mt)
  (missing-larkc "Generated metered/outer functions do not exist in Java; only the reset function is active."))

;; (defun sufficient-defns-admit-int (arg1 arg2 arg3 &optional arg4 arg5) ...) -- no body
;; (defun why-sufficient-defns-admit? (collection v-term &optional mt) ...) -- no body
;; (defun sufficient-defn-violation-data (arg1 arg2 arg3 arg4 &optional arg5) ...) -- no body
;; (defun necessary-defns-permit? (collection v-term &optional mt) ...) -- no body

(define-defn-metered necessary-defns-reject? (collection v-term mt)
  (missing-larkc "Generated metered/outer functions do not exist in Java; only the reset function is active."))

;; (defun necessary-defns-reject?-int (arg1 arg2 arg3 arg4 arg5 &optional arg6) ...) -- no body

(defun denotational-term-admitted-by-defn-via-isa? (v-term collection &optional mt)
  "[Cyc] Return T iff V-TERM is a denotational term admitted by defn via isa."
  (let ((admitted? nil))
    (when (permitting-denotational-terms-admitted-by-defn-via-isa?)
      (let ((*sbhl-table* (get-sbhl-marking-space)))
        (unwind-protect
             (setf admitted?
                   (and (at-denotational-term-p v-term)
                        (or (isa? v-term collection mt)
                            (and (gaf-assertion? *added-assertion*)
                                 (isa-lit? (gaf-formula *added-assertion*))
                                 (equal v-term (gaf-arg1 *added-assertion*))
                                 (genls? (gaf-arg2 *added-assertion*) collection mt))
                            (and (within-wff?)
                                 (within-assert?)
                                 (isa-lit? (wff-formula))
                                 (equal v-term (sentence-arg1 (wff-formula)))
                                 (el-fort-p (sentence-arg2 (wff-formula)))
                                 (genls? (sentence-arg2 (wff-formula)) collection mt)
                                 (not (el-negation-p (wff-formula)))))
                        t))
          (free-sbhl-marking-space *sbhl-table*))))
    admitted?))

(define-defn-metered rejected-by-necessary-defns (collection v-term mt)
  (missing-larkc "Generated metered/outer functions do not exist in Java; only the reset function is active."))

;; (defun why-defns-reject? (collection v-term &optional mt) ...) -- no body
;; (defun necessary-defn-violation-data (arg1 arg2 arg3 arg4 arg5 &optional arg6) ...) -- no body
;; (defun at-quoted-defns-admit? (arg1) ...) -- no body
;; (defun at-quoted-defns-reject? (arg1) ...) -- no body

(defun quoted-defns-admit? (collection v-term &optional (mt *mt*))
  "[Cyc] Return T iff the quoted defns of COLLECTION admit V-TERM."
  (if *use-new-defns-functions?*
      (new-quoted-defns-admit? collection v-term mt)
      (missing-larkc 5346)))

(define-defn-metered old-quoted-defns-admit? (collection v-term mt)
  (missing-larkc "Generated metered/outer functions do not exist in Java; only the reset function is active."))

;; (defun old-quoted-defns-admit?-metered (collection v-term &optional mt) ...) -- no body
;; (defun old-quoted-defns-admit? (collection v-term &optional mt) ...) -- no body
;; (defun quoted-defns-reject? (collection v-term &optional mt) ...) -- no body

(define-defn-metered old-quoted-defns-reject? (collection v-term mt)
  (missing-larkc "Generated metered/outer functions do not exist in Java; only the reset function is active."))

(define-defn-metered quoted-defining-defns-status (collection v-term mt)
  (missing-larkc "Generated metered/outer functions do not exist in Java; only the reset function is active."))

(define-defn-metered quoted-sufficient-defns-admit? (collection v-term mt)
  (missing-larkc "Generated metered/outer functions do not exist in Java; only the reset function is active."))

;; (defun quoted-necessary-defns-permit? (collection v-term &optional mt) ...) -- no body

(define-defn-metered quoted-necessary-defns-reject? (collection v-term mt)
  (missing-larkc "Generated metered/outer functions do not exist in Java; only the reset function is active."))

(defun denotational-term-admitted-by-quoted-defn-via-quoted-isa? (v-term collection &optional mt)
  "[Cyc] Return T iff V-TERM is a denotational term admitted by quoted defn via quoted-isa."
  (let ((admitted? nil))
    (when (permitting-denotational-terms-admitted-by-defn-via-isa?)
      (let ((*sbhl-table* (get-sbhl-marking-space)))
        (unwind-protect
             (setf admitted?
                   (and (at-denotational-term-p v-term)
                        (or (quoted-isa? v-term collection mt)
                            (and (gaf-assertion? *added-assertion*)
                                 (quoted-isa-lit? (gaf-formula *added-assertion*))
                                 (equal v-term (gaf-arg1 *added-assertion*))
                                 (genls? (gaf-arg2 *added-assertion*) collection mt))
                            (and (within-wff?)
                                 (within-assert?)
                                 (quoted-isa-lit? (wff-formula))
                                 (equal v-term (sentence-arg1 (wff-formula)))
                                 (el-fort-p (sentence-arg2 (wff-formula)))
                                 (genls? (sentence-arg2 (wff-formula)) collection mt)
                                 (not (el-negation-p (wff-formula)))))
                        t))
          (free-sbhl-marking-space *sbhl-table*))))
    admitted?))

(define-defn-metered rejected-by-quoted-necessary-defns (collection v-term mt)
  (missing-larkc "Generated metered/outer functions do not exist in Java; only the reset function is active."))

;; (defun why-quoted-defns-reject? (collection v-term &optional mt) ...) -- no body

(defun new-defn-stack ()
  "[Cyc] Create a new defn stack hash table."
  (make-hash-table :size 16))

(defun defn-stack-push (defn v-term)
  "[Cyc] Push V-TERM onto the defn stack for DEFN."
  (push-hash defn v-term *defn-stack*))

(defun defn-stack-pop (defn expected-term)
  "[Cyc] Pop the defn stack for DEFN, checking consistency."
  (let ((actual-term (pop-hash defn *defn-stack*)))
    (unless (equal expected-term actual-term)
      ;; As the function comment mentions checking consistency, this is a consistency failure
      (missing-larkc 5301))
    actual-term))

(defun recursive-defn-call? (defn v-term)
  "[Cyc] Return T iff calling DEFN with V-TERM would be recursive."
  (when (initialized-p *defn-stack*)
    (let ((term-stack (gethash defn *defn-stack*)))
      (member? v-term term-stack #'equal))))

;; (defun get-defn-col-history (defn) ...) -- 1 required, 0 optional, no body
;; (defun set-defn-col-history (defn result) ...) -- 2 required, 0 optional, no body

(defun get-defn-fn-history (defn)
  "[Cyc] Get the defn function history for DEFN."
  (gethash defn *defn-fn-history*))

(defun set-defn-fn-history (defn result)
  "[Cyc] Set the defn function history for DEFN to RESULT."
  (setf (gethash defn *defn-fn-history*) result))

(defun get-quoted-defn-fn-history (defn)
  "[Cyc] Get the quoted defn function history for DEFN."
  (gethash defn *quoted-defn-fn-history*))

;; (defun set-quoted-defn-fn-history (defn result) ...) -- 2 required, 0 optional, no body
;; (defun get-quoted-defn-col-history (defn) ...) -- 1 required, 0 optional, no body
;; (defun set-quoted-defn-col-history (defn result) ...) -- 2 required, 0 optional, no body

(defun quiet-defns-admit? (collection v-term &optional mt)
  "[Cyc] Return T iff some defn of COLLECTION admits V-TERM; don't generate violation messages."
  (let ((*noting-at-violations?* nil)
        (*accumulating-at-violations?* nil)
        (*noting-wff-violations?* nil)
        (*accumulating-wff-violations?* nil))
    (defns-admit? collection v-term mt)))

;; (defun quiet-sufficient-defns-admit? (collection v-term &optional mt) ...) -- no body (present in Java but only active in declare as commented)
;; (defun quiet-defns-reject? (collection v-term &optional mt) ...) -- no body

(defun quiet-defn-admits? (defn v-term collection &optional mt)
  "[Cyc] See if DEFN of COLLECTION admits V-TERM; don't generate violation messages."
  (let ((*noting-at-violations?* nil)
        (*accumulating-at-violations?* nil)
        (*noting-wff-violations?* nil)
        (*accumulating-wff-violations?* nil))
    (defn-admits? defn v-term collection mt)))

(defun defn-admits? (defn v-term collection &optional mt)
  "[Cyc] Does DEFN of COLLECTION admit V-TERM?"
  (let ((history (defn-history defn)))
    (cond
      ((eql history :admitted) t)
      ((eql history :rejected) nil)
      (t
       (when (recursive-defn-call? defn v-term)
         (missing-larkc 5302)
         (return-from defn-admits? nil))
       (let ((admits? nil))
         (let ((*defn-stack* (if (uninitialized-p *defn-stack*)
                                 (new-defn-stack)
                                 *defn-stack*)))
           (unwind-protect
                (progn
                  (defn-stack-push defn v-term)
                  (let ((*relevant-mt-function* (possibly-in-mt-determine-function mt))
                        (*mt* (possibly-in-mt-determine-mt mt)))
                    (setf admits? (defn-admits-int? defn v-term collection))))
             (defn-stack-pop defn v-term)))
         (when (not (collection-specific-defn? defn))
           (if admits?
               (set-defn-fn-history defn :admitted)
               (set-defn-fn-history defn :rejected)))
         admits?)))))

(defun collection-specific-defn? (symbol)
  "[Cyc] Return T iff SYMBOL is a collection-specific defn."
  (member? symbol *at-collection-specific-defns*))

(defun defn-history (defn)
  "[Cyc] Return the cached history (:admitted or :rejected) for DEFN, if any."
  (when (viable-defn? defn)
    (unless (collection-specific-defn? defn)
      (get-defn-fn-history defn))))

(define-defn-metered defn-admits-int? (defn v-term collection)
  (let ((admits? nil))
    (let ((*sbhl-table* (get-sbhl-marking-space)))
      (unwind-protect
           (setf admits? (and (or (denotational-term-admitted-by-defn-via-isa? v-term collection)
                                  (defn-funcall defn v-term))
                              t))
        (free-sbhl-marking-space *sbhl-table*)))
    (if (eq collection *defn-collection*)
        (defn-note 5 "~%defn test: term ~s; defn ~s of collection ~s: ~s"
                   v-term defn collection
                   (if admits? :admitted :rejected))
        (defn-note 5 "~%defn test: term ~s; defn ~s of collection ~s (via ~s): ~s"
                   v-term defn collection *defn-collection*
                   (if admits? :admitted :rejected)))
    admits?))

;; (defun quiet-quoted-defns-admit? (collection v-term &optional mt) ...) -- no body
;; (defun quiet-quoted-sufficient-defns-admit? (collection v-term &optional mt) ...) -- no body
;; (defun quiet-quoted-defns-reject? (collection v-term &optional mt) ...) -- no body
;; (defun quiet-quoted-defn-admits? (defn v-term collection &optional mt) ...) -- no body

(defun quoted-defn-admits? (defn v-term collection &optional mt)
  "[Cyc] Does quoted DEFN of COLLECTION admit V-TERM?"
  (let ((history (quoted-defn-history defn)))
    (cond
      ((eql history :admitted) t)
      ((eql history :rejected) nil)
      (t
       (when (recursive-defn-call? defn v-term)
         (missing-larkc 5303)
         (return-from quoted-defn-admits? nil))
       (let ((admits? nil))
         (let ((*defn-stack* (if (uninitialized-p *defn-stack*)
                                 (new-defn-stack)
                                 *defn-stack*)))
           (unwind-protect
                (progn
                  (defn-stack-push defn v-term)
                  (let ((*relevant-mt-function* (possibly-in-mt-determine-function mt))
                        (*mt* (possibly-in-mt-determine-mt mt)))
                    (setf admits? (quoted-defn-admits-int? defn v-term collection))))
             (defn-stack-pop defn v-term)))
         (when (not (collection-specific-defn? defn))
           (if admits?
               (setf (gethash defn *quoted-defn-fn-history*) :admitted)
               (setf (gethash defn *quoted-defn-fn-history*) :rejected)))
         admits?)))))

(defun quoted-defn-history (defn)
  "[Cyc] Return the cached history for quoted DEFN."
  (when (viable-defn? defn)
    (unless (collection-specific-defn? defn)
      (get-quoted-defn-fn-history defn))))

(define-defn-metered quoted-defn-admits-int? (defn v-term collection)
  (let ((admits? nil))
    (let ((*sbhl-table* (get-sbhl-marking-space)))
      (unwind-protect
           (setf admits? (and (or (denotational-term-admitted-by-quoted-defn-via-quoted-isa?
                                   v-term collection)
                                  (defn-funcall defn v-term))
                              t))
        (free-sbhl-marking-space *sbhl-table*)))
    (if (eq collection *defn-collection*)
        (defn-note 5 "~%defn test: term ~s; defn ~s of collection ~s: ~s"
                   v-term defn collection
                   (if admits? :admitted :rejected))
        (defn-note 5 "~%defn test: term ~s; defn ~s of collection ~s (via ~s): ~s"
                   v-term defn collection *defn-collection*
                   (if admits? :admitted :rejected)))
    admits?))

;; TODO - is this part of the defn-cyc-evaluate caching state?
(defun clear-defn-cyc-evaluate ()
  "[Cyc] Clear the defn-cyc-evaluate caching state."
  (let ((cs *defn-cyc-evaluate-caching-state*))
    (when cs
      (caching-state-clear cs)))
  nil)

;; (defun remove-defn-cyc-evaluate (arg1) ...) -- 1 required, 0 optional, no body
;; (defun defn-cyc-evaluate-internal (arg1) ...) -- 1 required, 0 optional, no body
;; (defun defn-cyc-evaluate (arg1) ...) -- 1 required, 0 optional, no body

(defun valid-defn? (defn &optional defn-collection)
  "[Cyc] Return T iff DEFN is a valid defn."
  (when defn
    (let ((valid? (symbolp defn)))
      (unless valid?
        (if defn-collection
            (missing-larkc 5304)
            (missing-larkc 5305)))
      valid?)))

(defun viable-defn? (defn &optional defn-collection)
  "[Cyc] Return T iff DEFN is a viable defn."
  (when (valid-defn? defn)
    (let ((viable? (possibly-cyc-api-function-spec-p defn)))
      (unless viable?
        (if defn-collection
            (missing-larkc 5306)
            (missing-larkc 5307)))
      viable?)))

(defun defn-funcall (defn v-term)
  "[Cyc] Funcall DEFN on V-TERM, which returns non-NIL on success."
  (possibly-cyc-api-funcall-1 defn v-term))

(defun at-denotational-term-p (v-term &optional (var? #'cyc-var?))
  "[Cyc] Return T iff V-TERM is a denotational term for AT purposes."
  (or (fort-p v-term)
      (closed-naut? v-term var?)))

(defun clear-defn-space ()
  "[Cyc] Clear the defn space (evaluation cache)."
  (clear-defn-cyc-evaluate)
  nil)

;; (defun map-sufficient-defn-cols (arg1) ...) -- 1 required, 0 optional, no body

(defun has-type? (v-term collection &optional mt)
  "[Cyc] Return T iff V-TERM either isa COLLECTION (via isa sbhl module)
or admitted by (via defns module) COLLECTION."
  (cond
    ((ground-naut? collection) (has-type? v-term (find-ground-naut collection) mt))
    ((fort-p collection)
     (let ((*permitting-denotational-terms-admitted-by-defn-via-isa?* nil))
       (or (isa? v-term collection mt)
           (defns-admit? collection v-term mt)
           nil)))
    (t nil)))

(defun quiet-has-type? (v-term collection &optional mt)
  "[Cyc] Return T iff V-TERM isa COLLECTION or admitted by COLLECTION (quiet: no violations)."
  (cond
    ((ground-naut? collection) (quiet-has-type? v-term (find-ground-naut collection) mt))
    ((fort-p collection)
     (let ((*permitting-denotational-terms-admitted-by-defn-via-isa?* nil))
       (or (isa? v-term collection mt)
           (quiet-defns-admit? collection v-term mt)
           nil)))
    (t nil)))

;; (defun quiet-has-any-type? (v-term collection &optional mt) ...) -- no body

;; The Java had a hand-expanded DEFINE-MEMOIZED pattern here with sxhash-calc-4
;; and manual collision lists. In CL, defun-memoized handles all of this — the
;; 4-arg case uses (list v-term collection mt mt-info) as a hash key with :equal,
;; which CL hash tables handle natively. The mt-info param exists only as a cache
;; key component; it is not used in the actual computation.
;;
;; The Java declareFunction is (2,2) — 2 required, 2 optional. defun-memoized
;; needs all args required for uniform cache keys, so we use a thin wrapper.
(defun-memoized quiet-has-type-memoized?-memoized (v-term collection mt mt-info) (:test equal)
  (quiet-has-type? v-term collection mt))

(defun quiet-has-type-memoized? (v-term collection &optional mt (mt-info (mt-info)))
  "[Cyc] Memoized check whether V-TERM has type COLLECTION."
  (quiet-has-type-memoized?-memoized v-term collection mt mt-info))

;; (defun not-has-type-by-extent-known? (v-term collection &optional mt) ...) -- no body
;; (defun not-has-type? (v-term collection &optional mt) ...) -- no body
;; (defun quiet-not-has-type? (v-term collection &optional mt) ...) -- no body
;; (defun quick-quiet-has-type? (v-term collection &optional mt) ...) -- no body
;; (defun quick-quiet-has-type?-fort (arg1 arg2 arg3) ...) -- no body
;; (defun quick-quiet-has-type?-naut (arg1 arg2 arg3) ...) -- no body
;; (defun max-mts-of-admitting-defns (arg1 arg2) ...) -- no body
;; (defun mts-of-admitting-sufficient-defns (arg1 arg2) ...) -- no body
;; (defun old-mts-of-admitting-sufficient-defns (arg1 arg2) ...) -- no body
;; (defun max-mts-of-admitting-quoted-defns (arg1 arg2) ...) -- no body
;; (defun mts-of-admitting-sufficient-quoted-defns (arg1 arg2) ...) -- no body
;; (defun isa-via-defns? (v-term collection &optional mt) ...) -- no body
;; (defun hl-justify-isa-via-defns (v-term collection &optional mt) ...) -- no body
;; (defun old-hl-justify-isa-via-defns (v-term collection &optional mt) ...) -- no body
;; (defun not-isa-via-defns? (v-term collection &optional mt) ...) -- no body
;; (defun why-not-isa-via-defns? (v-term collection &optional mt) ...) -- no body
;; (defun hl-justify-not-isa-via-defns (v-term collection &optional mt) ...) -- no body
;; (defun collection-rejects-via-disjoint-defns? (v-term collection &optional mt) ...) -- no body
;; (defun why-collection-rejects-via-disjoint-defns? (v-term collection &optional mt) ...) -- no body
;; (defun collections-admitting-term-via-defns (arg1) ...) -- no body
;; (defun min-max-collections-admitting-term-via-defns (arg1 &optional arg2) ...) -- no body
;; (defun collections-admitting-term-via-defns-1 (arg1) ...) -- no body
;; (defun gather-collections-admitting-via-defns (arg1) ...) -- no body

(defun defn-note (level format-str &optional arg1 arg2 arg3 arg4 arg5 arg6)
  "[Cyc] Print a defn trace note at LEVEL."
  (when (>= *defn-trace-level* level)
    (format t format-str arg1 arg2 arg3 arg4 arg5 arg6))
  nil)

;; (defun defn-error (level format-str &optional arg1 arg2 arg3 arg4 arg5) ...) -- no body
;; (defun defn-cerror (level continue-str format-str &optional arg1 arg2 arg3 arg4 arg5) ...) -- no body
;; (defun defn-warn (level format-str &optional arg1 arg2 arg3 arg4 arg5) ...) -- no body
;; (defun reset-defn-meters () ...) -- no body
;; (defun report-defn-meters (&optional arg1) ...) -- no body
;; (defun summarize-defn-meters (&optional arg1) ...) -- no body
;; (defun summarize-defn-meter-cache-header (&optional arg1 arg2) ...) -- no body
;; (defun summarize-defn-meter-cache (arg1 &optional arg2 arg3) ...) -- no body
;; (defun summarize-defn-meter-cache-trailer (&optional arg1 arg2) ...) -- no body
;; (defun report-defn-meter-cache (arg1 &optional arg2) ...) -- no body
;; (defun report-defn-meter-cache-header (arg1 &optional arg2 arg3) ...) -- no body
;; (defun report-defn-meter-cache-trailer (arg1 &optional arg2 arg3) ...) -- no body
;; (defun report-defn-meter-cache-call (arg1 arg2 &optional arg3 arg4) ...) -- no body
;; (defun report-defn-meter-cache-total (arg1 &optional arg2 arg3) ...) -- no body
;; (defun function-col-width (arg1) ...) -- no body
;; (defun meter-col-widths (arg1) ...) -- no body
;; (defun suf-defn-assertions (arg1) ...) -- no body
;; (defun suf-defn? (arg1 arg2) ...) -- no body
;; (defun old-suf-defn? (arg1 arg2) ...) -- no body

(defun any-sufficient-defn-anywhere? (collection)
  "[Cyc] Return T iff there is any sufficient defn anywhere for COLLECTION."
  (if *use-new-defns-functions?*
      (has-suf-defn-somewhere? collection nil)
      (missing-larkc 5338)))

;; (defun old-any-sufficient-defn-anywhere? (collection) ...) -- no body
;; (defun suf-defn-assertion? (arg1 arg2) ...) -- no body
;; (defun add-suf-defn (arg1 arg2) ...) -- no body
;; (defun add-iff-defn (arg1 arg2) ...) -- no body
;; (defun old-add-suf-defn (arg1 arg2) ...) -- no body
;; (defun remove-suf-defn (arg1 arg2) ...) -- no body
;; (defun remove-iff-defn (arg1 arg2) ...) -- no body
;; (defun old-remove-suf-defn (arg1 arg2) ...) -- no body

(define-defn-metered cache-suf-defn (col assertion)
  (missing-larkc "Generated metered/outer functions do not exist in Java; only the reset function is active."))

(define-defn-metered uncache-suf-defn (col assertion)
  (missing-larkc "Generated metered/outer functions do not exist in Java; only the reset function is active."))

;; (defun cache-suf-defn-int (arg1 arg2 &optional arg3) ...) -- no body
;; (defun uncache-suf-defn-int (arg1 arg2 &optional arg3) ...) -- no body

(defun handle-added-genl-for-suf-defns (spec genl)
  "[Cyc] Handle added genl for sufficient defns."
  (if *use-new-defns-functions?*
      (new-handle-added-genl-for-suf-defns spec genl)
      (missing-larkc 5342)))

(define-defn-metered old-handle-added-genl-for-suf-defns (spec genl)
  (missing-larkc "Generated metered/outer functions do not exist in Java; only the reset function is active."))

(defun handle-removed-genl-for-suf-defns (spec genl)
  "[Cyc] Handle removed genl for sufficient defns."
  (if *use-new-defns-functions?*
      (new-handle-removed-genl-for-suf-defns spec genl)
      (missing-larkc 5344)))

(define-defn-metered old-handle-removed-genl-for-suf-defns (spec genl)
  (missing-larkc "Generated metered/outer functions do not exist in Java; only the reset function is active."))

;; (defun propagate-added-suf-defn (arg1 arg2) ...) -- no body
;; (defun propagate-removed-suf-defn (arg1 arg2) ...) -- no body
;; (defun propagate-added-suf-defns (arg1 arg2) ...) -- no body
;; (defun propagate-removed-suf-defns (arg1 arg2) ...) -- no body
;; (defun add-suf-defn-assertion (&optional arg1 arg2) ...) -- no body
;; (defun remove-suf-defn-assertion (&optional arg1 arg2) ...) -- no body
;; (defun merge-suf-defn-assertions (&optional arg1 arg2) ...) -- no body
;; (defun defn-genl-searched? (arg1) ...) -- no body
;; (defun arg1-spec-cardinality (arg1) ...) -- no body
;; (defun suf-defn-sort (arg1) ...) -- no body
;; (defun reset-col-suf-defns (arg1) ...) -- no body
;; (defun reset-all-suf-defns (&optional arg1 arg2) ...) -- no body
;; (defun initialize-sufficient-defns-cache () ...) -- no body
;; (defun suf-quoted-defn-assertions (arg1) ...) -- no body
;; (defun suf-quoted-defn? (arg1 arg2) ...) -- no body
;; (defun any-sufficient-quoted-defn? (arg1 &optional arg2) ...) -- no body

(defun any-sufficient-quoted-defn-anywhere? (collection)
  "[Cyc] Return T iff there is any sufficient quoted defn anywhere for COLLECTION."
  (if *use-new-defns-functions?*
      (has-suf-defn-somewhere? collection t)
      (missing-larkc 5339)))

;; (defun old-any-sufficient-quoted-defn-anywhere? (collection) ...) -- no body
;; (defun suf-quoted-defn-assertion? (arg1 arg2) ...) -- no body

(defun quoted-has-type? (v-term collection &optional mt)
  "[Cyc] Return T iff V-TERM either isa COLLECTION (via quoted-isa sbhl module)
or admitted by (via defns module) COLLECTION."
  (cond
    ((ground-naut? collection) (quoted-has-type? v-term (find-ground-naut collection) mt))
    ((fort-p collection)
     (or (quoted-isa? v-term collection mt)
         (quoted-defns-admit? collection v-term mt)
         nil))
    (t nil)))

;; (defun quiet-quoted-has-type? (v-term collection &optional mt) ...) -- no body
;; (defun not-quoted-has-type-by-extent-known? (v-term collection &optional mt) ...) -- no body
;; (defun not-quoted-has-type? (v-term collection &optional mt) ...) -- no body
;; (defun quiet-not-quoted-has-type? (v-term collection &optional mt) ...) -- no body
;; (defun add-suf-quoted-defn (arg1 arg2) ...) -- no body
;; (defun add-iff-quoted-defn (arg1 arg2) ...) -- no body
;; (defun old-add-suf-quoted-defn (arg1 arg2) ...) -- no body
;; (defun remove-suf-quoted-defn (arg1 arg2) ...) -- no body
;; (defun remove-iff-quoted-defn (arg1 arg2) ...) -- no body
;; (defun old-remove-suf-quoted-defn (arg1 arg2) ...) -- no body

(define-defn-metered cache-suf-quoted-defn (col assertion)
  (missing-larkc "Generated metered/outer functions do not exist in Java; only the reset function is active."))

(define-defn-metered uncache-suf-quoted-defn (col assertion)
  (missing-larkc "Generated metered/outer functions do not exist in Java; only the reset function is active."))

;; (defun cache-suf-quoted-defn-int (arg1 arg2 &optional arg3) ...) -- no body
;; (defun uncache-suf-quoted-defn-int (arg1 arg2 &optional arg3) ...) -- no body

(defun handle-added-genl-for-suf-quoted-defns (spec genl)
  "[Cyc] Handle added genl for sufficient quoted defns."
  (if *use-new-defns-functions?*
      (new-handle-added-genl-for-suf-quoted-defns spec genl)
      (missing-larkc 5343)))

(define-defn-metered old-handle-added-genl-for-suf-quoted-defns (spec genl)
  (missing-larkc "Generated metered/outer functions do not exist in Java; only the reset function is active."))

(defun handle-removed-genl-for-suf-quoted-defns (spec genl)
  "[Cyc] Handle removed genl for sufficient quoted defns."
  (if *use-new-defns-functions?*
      (new-handle-removed-genl-for-suf-quoted-defns spec genl)
      (missing-larkc 5345)))

(define-defn-metered old-handle-removed-genl-for-suf-quoted-defns (spec genl)
  (missing-larkc "Generated metered/outer functions do not exist in Java; only the reset function is active."))

;; (defun propagate-added-suf-quoted-defn (arg1 arg2) ...) -- no body
;; (defun propagate-removed-suf-quoted-defn (arg1 arg2) ...) -- no body
;; (defun propagate-added-suf-quoted-defns (arg1 arg2) ...) -- no body
;; (defun propagate-removed-suf-quoted-defns (arg1 arg2) ...) -- no body
;; (defun add-suf-quoted-defn-assertion (&optional arg1 arg2) ...) -- no body
;; (defun remove-suf-quoted-defn-assertion (&optional arg1 arg2) ...) -- no body
;; (defun merge-suf-quoted-defn-assertions (&optional arg1 arg2) ...) -- no body
;; (defun reset-col-suf-quoted-defns (arg1) ...) -- no body
;; (defun reset-all-suf-quoted-defns (&optional arg1 arg2) ...) -- no body
;; (defun initialize-sufficient-quoted-defns-cache () ...) -- no body

(defun suf-function-cache (type)
  "[Cyc] Return the appropriate sufficient function cache for TYPE."
  (cond
    ((eql type :isa) *suf-function-cache*)
    ((eql type :quoted-isa) *suf-quoted-function-cache*)
    (t nil)))

(defun get-suf-function-assertions (collection type)
  "[Cyc] Get the sufficient function assertions for COLLECTION of TYPE."
  (gethash collection (suf-function-cache type)))

;; (defun set-suf-function-assertions (collection type value) ...) -- no body
;; (defun rem-suf-function-assertions (collection type) ...) -- no body

(defun suf-function-assertions (collection type)
  "[Cyc] Return the sufficient function assertions for COLLECTION of TYPE.
Note: the fort-p branch calls get-suf-function-assertions but discards the result
and returns NIL. This matches the Java source — likely a bug in the original."
  (cond
    ((fort-p collection)
     (get-suf-function-assertions collection type))
    ((reifiable-nat? collection)
     (suf-function-assertions (missing-larkc 10323) type))))

;; (defun suf-function? (arg1 arg2 arg3) ...) -- no body
;; (defun any-sufficient-function? (arg1 &optional arg2) ...) -- no body
;; (defun any-sufficient-quoted-function? (arg1 &optional arg2) ...) -- no body
;; (defun any-sufficient-function?-int (arg1 arg2 arg3) ...) -- no body
;; (defun any-sufficient-non-reified-function? (arg1 arg2 &optional arg3) ...) -- no body
;; (defun suf-function-assertion? (arg1 arg2 arg3) ...) -- no body
;; (defun sufficient-function-of (arg1 arg2 &optional arg3) ...) -- no body
;; (defun add-suf-function (arg1 arg2) ...) -- no body
;; (defun remove-suf-function (arg1 arg2) ...) -- no body
;; (defun add-suf-quoted-function (arg1 arg2) ...) -- no body
;; (defun remove-suf-quoted-function (arg1 arg2) ...) -- no body
;; (defun add-suf-function-int (arg1 arg2 arg3) ...) -- no body
;; (defun remove-suf-function-int (arg1 arg2 arg3) ...) -- no body

(define-defn-metered cache-suf-function (col assertion type)
  (missing-larkc "Generated metered/outer functions do not exist in Java; only the reset function is active."))

(define-defn-metered uncache-suf-function (col assertion type)
  (missing-larkc "Generated metered/outer functions do not exist in Java; only the reset function is active."))

;; (defun cache-suf-function-int (arg1 arg2 arg3 &optional arg4) ...) -- no body
;; (defun uncache-suf-function-int (arg1 arg2 arg3 &optional arg4) ...) -- no body

(define-defn-metered handle-added-genl-for-suf-functions (spec genl)
  (declare (ignore genl))
  (dolist (type '(:isa :quoted-isa))
    (let ((function-assertions (suf-function-assertions spec type)))
      (when function-assertions
        (missing-larkc 5353))))
  nil)

(define-defn-metered handle-removed-genl-for-suf-functions (spec genl)
  (let ((*relevant-mt-function* #'relevant-mt-is-everything)
        (*mt* #$EverythingPSC))
    (unless (genl? spec genl)
      (dolist (type '(:isa :quoted-isa))
        (let ((function-assertions (suf-function-assertions spec type)))
          (when function-assertions
            (let ((resourcing-p (resourcing-sbhl-marking-spaces-p)))
              (let ((*resourcing-sbhl-marking-spaces-p* nil)
                    (*sbhl-table* (get-sbhl-marking-space)))
                (unwind-protect
                     (let ((*at-genls-space* *sbhl-table*)
                           (*resourcing-sbhl-marking-spaces-p* resourcing-p))
                       (missing-larkc 1466)
                       (missing-larkc 5356))
                  (free-sbhl-marking-space *sbhl-table*)))))))))
  nil)

;; (defun propagate-added-suf-function (arg1 arg2 arg3) ...) -- no body
;; (defun propagate-removed-suf-function (arg1 arg2 arg3) ...) -- no body
;; (defun propagate-added-suf-functions (arg1 arg2 arg3) ...) -- no body
;; (defun propagate-removed-suf-functions (arg1 arg2 arg3) ...) -- no body
;; (defun add-suf-function-assertion (&optional arg1 arg2) ...) -- no body
;; (defun remove-suf-function-assertion (&optional arg1 arg2) ...) -- no body
;; (defun merge-suf-function-assertions (&optional arg1 arg2) ...) -- no body
;; (defun remove-suf-function-assertions (&optional arg1 arg2) ...) -- no body
;; (defun add-suf-quoted-function-assertion (&optional arg1 arg2) ...) -- no body
;; (defun remove-suf-quoted-function-assertion (&optional arg1 arg2) ...) -- no body
;; (defun merge-suf-quoted-function-assertions (&optional arg1 arg2) ...) -- no body
;; (defun remove-suf-quoted-function-assertions (&optional arg1 arg2) ...) -- no body
;; (defun merge-suf-function-assertions-int (arg1 arg2 arg3) ...) -- no body
;; (defun remove-suf-function-assertions-int (arg1 arg2 arg3) ...) -- no body
;; (defun function-genl-searched? (arg1) ...) -- no body
;; (defun suf-function-sort (arg1) ...) -- no body
;; (defun suf-function-sort-pred (arg1 arg2) ...) -- no body

(defun clear-suf-functions ()
  "[Cyc] Clear the sufficient function cache for :isa."
  (clrhash (suf-function-cache :isa))
  nil)

(defun clear-suf-quoted-functions ()
  "[Cyc] Clear the sufficient function cache for :quoted-isa."
  (clrhash (suf-function-cache :quoted-isa))
  nil)

;; (defun reset-col-suf-functions (arg1 arg2) ...) -- no body
;; (defun reset-all-suf-functions (arg1 &optional arg2 arg3) ...) -- no body
;; (defun initialize-sufficient-functions-cache () ...) -- no body
;; (defun initialize-sufficient-quoted-functions-cache () ...) -- no body
;; (defun sufficient-function-cache-mal-assertions (&optional arg1) ...) -- no body
;; (defun sufficient-function-cache-mal-assertions-coerce (&optional arg1) ...) -- no body
;; (defun assertion-referenced-in-sufficient-function-cache? (arg1 arg2) ...) -- no body
;; (defun diagnose-sufficient-functions-cache (arg1 &optional arg2 arg3) ...) -- no body
;; (defun kbi-sfc-status (&optional arg1) ...) -- no body
;; (defun sfc-cleanup (arg1) ...) -- no body
;; (defun sfc-mal-assertions (arg1) ...) -- no body

;;; ====== Init Phase ======

(defvar *use-new-defns-functions?* t)

;; Metering caches are created by define-defn-metered macro expansions above.
;; The following are additional init-phase variables.

(deflexical *defn-cyc-evaluate-caching-state* nil)

(defparameter *cat-defns-failing* nil
  "[Cyc] Hashtable of defns that fail for term.")

;; Diagnostic variables for sufficient function cache
(defparameter *suf-function-cache-mal-keys* nil
  "[Cyc] Invalid keys of suf-function cache.")
(defparameter *suf-function-cache-key-w/o-value* nil
  "[Cyc] Keys of suf-function cache that have no value.")
(defparameter *suf-function-cache-key-w/mal-value* nil
  "[Cyc] Keys of suf-function cache that have an invalid value.")
(defparameter *suf-function-cache-key-w/stale-value* nil
  "[Cyc] Keys of suf-function cache that have an inappropriate indirect value.")
(defparameter *suf-function-cache-keys-w/o-inerited-value* nil
  "[Cyc] Keys of suf-function cache that are missing an indirect value.")
(defparameter *suf-function-cache-awol-direct-assertions* nil
  "[Cyc] Assertions missing as direct values from suf-function cache.")

;;; ====== Setup Phase ======

;; define-defn-metered expansions handle all the metering setup (register state var,
;; call reset, set :reset key, clean old caches, push to *defn-meter-caches*).

;; Additional setup-phase registrations:
(toplevel
  (note-globally-cached-function 'defn-cyc-evaluate)
  ;; note-memoized-function for quiet-has-type-memoized? is now generated by defun-memoized
  ;; kb function registrations for commented-out functions
  (register-kb-function 'add-suf-defn)
  (register-kb-function 'add-iff-defn)
  (register-kb-function 'old-add-suf-defn)
  (register-kb-function 'remove-suf-defn)
  (register-kb-function 'remove-iff-defn)
  (register-kb-function 'old-remove-suf-defn)
  (register-kb-function 'add-suf-quoted-defn)
  (register-kb-function 'add-iff-quoted-defn)
  (register-kb-function 'old-add-suf-quoted-defn)
  (register-kb-function 'remove-suf-quoted-defn)
  (register-kb-function 'remove-iff-quoted-defn)
  (register-kb-function 'old-remove-suf-quoted-defn)
  (register-kb-function 'add-suf-function)
  (register-kb-function 'remove-suf-function)
  (register-kb-function 'add-suf-quoted-function)
  (register-kb-function 'remove-suf-quoted-function)
  (register-kb-function 'add-suf-function-int)
  (register-kb-function 'remove-suf-function-int))
