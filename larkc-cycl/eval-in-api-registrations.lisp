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

;;; Macro: API-BQ-LIST
;;; Reconstructed from Internal Constants: $sym35$LIST is the only orphan constant,
;;; used by the API-BQ-LIST macro body. This macro is the API evaluator's version
;;; of BQ-LIST (backquote list construction). It expands to a LIST call.
(defmacro api-bq-list (&rest args)
  `(list ,@args))

;;; Variables

(deflexical *sublisp-api-predefined-functions*
  '(* + - / /= < <= = > > >= abs acons acos adjoin alpha-char-p alphanumericp
    append aref ash asin assoc assoc-if atan atom boole boolean both-case-p
    bq-cons bq-vector butlast byte caar cadr car cconcatenate cdar cddr cdr
    ceiling cerror char char-code char-downcase char-equal char-greaterp
    char-lessp char-not-equal char-not-greaterp char-not-lessp char-upcase
    char/= char< char<= char= char> char>= characterp clrhash cmerge
    code-char cons consp constantp construct-filename copy-alist copy-list
    copy-seq copy-tree cos count count-if creduce current-process
    date-relative-guid-p decode-float decode-universal-time delete
    delete-duplicates delete-if digit-char digit-char-p
    disassemble-integer-to-fixnums dpb eighth elt encode-universal-time endp
    eq eql equal equalp evenp exit exp expt false fifth fill find find-if
    find-package find-symbol first fixnump float float-digits float-radix
    float-sign floatp floor force-output format fourth fresh-line
    function-spec-p functionp gc gc-dynamic gc-ephemeral gc-full gensym
    gentemp get get-decoded-time get-internal-real-time get-internal-real-time
    get-internal-run-time get-universal-time get-universal-time getf gethash
    gethash-without-values guid-p guid-string-p guid-to-string guid/= guid<
    guid<= guid= guid> guid>= hash-table-count hash-table-p hash-table-size
    hash-table-test identity ignore infinity-p int/ integer-decode-float
    integer-length integerp intern interrupt-process intersection isqrt
    keywordp kill-process last ldb ldiff length lisp-implementation-type
    lisp-implementation-version list list* list-all-packages list-length listp
    listp lock-idle-p lock-p log logand logandc1 logandc2 logbitp logcount
    logeqv logior lognand lognor lognot logorc1 logorc2 logtest logxor
    lower-case-p make-hash-table make-lock make-lock make-string makunbound
    max member member-if min minusp mismatch mod nbutlast nconc new-guid
    nintersection ninth not-a-number-p note-percent-progress notify nreconc
    nreverse nset-difference nset-exclusive-or nstring-capitalize
    nstring-downcase nstring-upcase nsublis nsubst nsubst-if nsubstitute
    nsubstitute-if nth nthcdr null numberp numberp nunion oddp pairlis
    peek-char plusp position position-if prin1 prin1-to-string princ
    princ-to-string print process-active-p process-block process-name
    process-state process-unblock process-wait process-wait-with-timeout
    process-whostate processp random rassoc rassoc-if read-from-string
    read-from-string-ignoring-errors rem remf remhash remove remove-duplicates
    remove-if replace rest revappend reverse reverse room round rplaca rplacd
    scale-float search second seed-random sequencep set-aref set-consing-state
    set-difference set-nth seventh show-processes sin sixth
    quit ;; SUBLISP:QUIT in Java
    sleep sort sqrt stable-sort string string-capitalize string-downcase
    string-equal string-greaterp string-left-trim string-lessp string-not-equal
    string-not-greaterp string-not-lessp string-right-trim string-to-guid
    string-trim string-upcase string/= string< string<= string= string>
    string>= stringp sublis subseq subsetp subst subst-if substitute
    substitute-if sxhash symbol-function symbol-name symbolp symbolp tailp tan
    tenth terpri third tree-equal true truncate type-of unintern union
    upper-case-p valid-process-p values vector vectorp warn write-image
    y-or-n-p yes-or-no-p zerop
    property-list-member ;; SUBLISP:PROPERTY-LIST-MEMBER in Java
    cdestructuring-bind-error ;; SUBLISP:CDESTRUCTURING-BIND-ERROR in Java
    destructuring-bind-must-consp ;; SUBLISP:DESTRUCTURING-BIND-MUST-CONSP in Java
    destructuring-bind-must-listp ;; SUBLISP:DESTRUCTURING-BIND-MUST-LISTP in Java
    ))

(deflexical *api-host-access-functions*
  '(broadcast-stream-streams clear-input clear-output close
    concatenated-stream-streams construct-filename current-process cyc-image-id
    directory directory-p echo-stream-input-stream echo-stream-output-stream
    endp file-author file-length file-position file-string-length
    file-write-date finish-output getf get-file-position get-machine-name
    get-network-name get-output-stream-string get-process-id
    get-string-from-user get-user-name input-stream-p interactive-stream-p
    intern interrupt-process keywordp kill-process lisp-implementation-type
    lisp-implementation-version listen long-site-name machine-instance
    machine-type machine-version make-broadcast-stream make-concatenated-stream
    make-directory make-echo-stream make-keyword make-list make-lock
    make-package make-process make-string-input-stream make-string-output-stream
    make-synonym-stream make-two-way-stream open open-binary open-stream-p
    open-tcp-stream open-tcp-stream-with-timeout open-text output-stream-p
    package-locked-p package-name package-nicknames packagep
    package-used-by-list package-use-list peek-char probe-file
    process-active-p process-block process-name processp process-state
    process-unblock process-wait process-wait-with-timeout process-whostate
    put putf read read-byte read-char read-char-no-hang read-delimited-list
    read-ignoring-errors read-line read-preserving-whitespace read-sequence
    remprop rename-file short-site-name server-summary show-processes
    simple-reader-error software-type software-version streamp
    synonym-stream-symbol two-way-stream-input-stream
    two-way-stream-output-stream unread-char user-confirm valid-process-p
    write write-byte write-char write-line write-sequence write-string
    write-to-string))

;;; Setup phase — API registrations

;; Immutable globals
(register-api-immutable-global '*null-output*)

;; Mutable globals
(register-api-mutable-global '*it-verbose*)
(register-api-mutable-global '*progress-note*)
(register-api-mutable-global '*progress-sofar*)
(register-api-mutable-global '*progress-start-time*)
(register-api-mutable-global '*progress-total*)
(register-api-mutable-global '*eval-with-bindings*)
(register-api-mutable-global '*error-output*)
(register-api-mutable-global '*standard-output*)
(register-api-mutable-global '*continue-cerror?*)
(register-api-mutable-global '*silent-progress?*)
(register-api-mutable-global '*ignore-breaks?*)
(register-api-mutable-global '*ignore-warns?*)
(register-api-mutable-global '*eval-in-api-trace-log*)
(register-api-mutable-global '*eval-in-api-traced-fns*)
(register-api-mutable-global '*eval-in-api-env*)
(register-api-mutable-global '*api-output-protocol*)
(register-api-mutable-global '*api-result-method*)
(register-api-mutable-global '*api-input-protocol*)
(register-api-mutable-global '*ke-purpose*)
(register-api-mutable-global '*the-cyclist*)
(register-api-mutable-global '*use-local-queue?*)
(register-api-mutable-global '*relevant-mt-function*)
(register-api-mutable-global '*cyc-bookkeeping-info*)
(register-api-mutable-global '*suppress-sbhl-recaching?*)
(register-api-mutable-global '*paraphrase-precision*)
(register-api-mutable-global '*eval-in-api-level*)
(register-api-mutable-global '*suspend-sbhl-type-checking?*)
(register-api-mutable-global '*require-case-insensitive-name-uniqueness*)
(register-api-mutable-global '*task-processor-verbosity*)

;; Predefined macros
(register-api-predefined-macro 'bq-append)
(register-api-predefined-macro 'bq-list)
(register-api-predefined-macro 'bq-list*)
(register-api-predefined-macro 'bq-nconc)
(register-api-predefined-macro 'bq-vector-append)
(register-api-predefined-macro 'api-bq-list)
(register-api-predefined-macro 'cdestructuring-bind)
(register-api-predefined-macro 'with-precise-paraphrase-on)
(register-api-predefined-macro 'with-paraphrase-precision)
(register-api-predefined-macro 'with-bookkeeping-info)
(register-api-predefined-macro 'with-mt-function)
(register-api-predefined-macro 'with-genl-mts)
(register-api-predefined-macro 'with-inference-mt-relevance)
(register-api-predefined-macro 'with-all-mts)
(register-api-predefined-macro 'do-predicate-rule-index)
(register-api-predefined-macro 'do-rule-index)
(register-api-predefined-macro 'without-wff-semantics)
(register-api-predefined-macro 'cdolist-done)
(register-api-predefined-macro 'do-dictionary)
(register-api-predefined-macro 'progress-cdotimes)
(register-api-predefined-macro 'do-kb-suid-table)
(register-api-predefined-macro 'do-id-index)
(register-api-predefined-macro 'old-do-id-index)
(register-api-predefined-macro 'do-constants)
(register-api-predefined-macro 'cwith-output-to-string)
(register-api-predefined-macro 'with-input-from-string)
(register-api-predefined-macro 'do-vector-index)
(register-api-predefined-macro 'in-mt)

;; Predefined host macros
(register-api-predefined-host-macro 'with-open-stream)
(register-api-predefined-host-macro 'with-open-file)
(register-api-predefined-host-macro 'with-tcp-connection)

;; Predefined functions from *sublisp-api-predefined-functions*
(dolist (symbol *sublisp-api-predefined-functions*)
  (register-api-predefined-function symbol))

;; Additional predefined functions (batch 1 — $list63)
(dolist (symbol '(add1 add2 api-dynamic-variable-p api-lexical-variable-p
                  api-test-fn b-verify booleanp cfasl-load copy-hash-table
                  cyc-image-id cycl-patch-number cycl-system-number
                  def-inference-test define-inference-test div2
                  eval-in-api-predefined-fn? eval-in-api-user-fn?
                  float-parse-integer flonum-digit-list frob-case
                  generate-stale-documentation-report get-time get-timezone
                  halt-cyc-image herald-start kb-loaded load-world lock-locker
                  lock-name macrop max2 member? min2 minus mult2 name-character
                  nconc2 non-negative-integer-p non-terminating-macro-syntaxp
                  not-a-list-argument possibly-gc potential-number-p
                  print-assert print-create print-kill process-valid-p
                  process-yield quit random-assertion random-constant
                  random-nart release-lock round-digits run-test seize-lock
                  sformp single-byte-p string-designatorp sub1 sub2
                  update-test-results whitespace-1-char-p whitespace-2-char-p))
  (register-api-predefined-function symbol))

;; Additional predefined functions (batch 2 — $list64, dictionary operations)
(dolist (symbol '(new-dictionary dictionary-length clear-dictionary
                  dictionary-enter dictionary-push dictionary-pushnew
                  dictionary-remove-from-value dictionary-remove
                  dictionary-lookup dictionary-keys dictionary-values))
  (register-api-predefined-function symbol))

;; Individual predefined functions
(register-api-predefined-function 'string-to-guid)
(register-api-predefined-function 'guid-to-string)
(register-api-predefined-function 'remove-duplicates)
(register-api-predefined-function 'new-bookkeeping-info)
(register-api-predefined-function 'string-substitute)
(register-api-predefined-function 'generate-phrase)
(register-api-predefined-function 'the-date)
(register-api-predefined-function 'the-second)
(register-api-predefined-function 'isa)
(register-api-predefined-function 'genls)
(register-api-predefined-function 'why-collections-intersect?)
(register-api-predefined-function 'arg1-format)
(register-api-predefined-function 'arg2-format)
(register-api-predefined-function 'specs)
(register-api-predefined-function 'collection-leaves)
(register-api-predefined-function 'simple-indexed-term-p)
(register-api-predefined-function 'max-specs)
(register-api-predefined-function 'min-isa)
(register-api-predefined-function 'local-disjoint-with)
(register-api-predefined-function 'disjoint-with?)
(register-api-predefined-function 'genl-siblings)
(register-api-predefined-function 'spec-siblings)
(register-api-predefined-function 'arg1-isa)
(register-api-predefined-function 'arg2-isa)
(register-api-predefined-function 'argn-isa)
(register-api-predefined-function 'argn-isa) ;; duplicate in Java
(register-api-predefined-function 'argn-genl)
(register-api-predefined-function 'all-genls-in-any-mt)
(register-api-predefined-function 'all-isa-in-any-mt)
(register-api-predefined-function 'all-fort-instances-in-all-mts)
(register-api-predefined-function 'isa-in-any-mt?)
(register-api-predefined-function 'genl-in-any-mt?)
(register-api-predefined-function 'new-constant-name-spec-p)
(register-api-predefined-function 'do-rule-index-rules)
(register-api-predefined-function 'bt-lower)
(register-api-predefined-function 'bt-higher)
(register-api-predefined-function 'sample-leaf-specs)
(register-api-predefined-function 'tacit-coextensional?)
(register-api-predefined-function 'el-wff?)
(register-api-predefined-function 'evaluatable-predicate?)
(register-api-predefined-function 'hierarchical-collections?)
(register-api-predefined-function 'num-best-gaf-lookup-index)
(register-api-predefined-function 'api-quit)
(register-api-predefined-function 'nart-p)
(register-api-predefined-function 'el-variable-p)
(register-api-predefined-function 'pph-precision-p)
(register-api-predefined-function 'fort-for-string)
(register-api-predefined-function 'rtp-parse-exp-w/vpp)
(register-api-predefined-function 'get-universal-time)
(register-api-predefined-function 'decode-universal-time)
(register-api-predefined-function 'find-nart)
(register-api-predefined-function 'constant-guid)
(register-api-predefined-function 'rkf-phrase-reader)
(register-api-predefined-function 'generate-disambiguation-phrases-and-types)
(register-api-predefined-function 'load-transcript-file)
(register-api-predefined-function 'kb-statistics)
(register-api-predefined-function 'genl-mt?)
(register-api-predefined-function 'all-spec-mts)
(register-api-predefined-function 'removal-ask)
(register-api-predefined-function 'do-narts-table)
(register-api-predefined-function 'id-index-count)
(register-api-predefined-function 'id-index-old-objects)
(register-api-predefined-function 'id-index-empty-p)
(register-api-predefined-function 'id-index-new-id-threshold)
(register-api-predefined-function 'id-index-next-id)
(register-api-predefined-function 'cycl-nart-p)
(register-api-predefined-function 'cycl-naut-p)
(register-api-predefined-function 'resolve-new-constants)
(register-api-predefined-function 'cyc-opencyc-feature)
(register-api-predefined-function 'cyc-researchcyc-feature)
(register-api-predefined-function 'canonicalize-hlmt)
(register-api-predefined-function 'new-cyc-query)
(register-api-predefined-function 'register-solely-specific-removal-module-predicate)
(register-api-predefined-function 'inference-removal-module)
(register-api-predefined-function 'undeclare-inference-removal-module)

;; Batch 3 — $list139
(dolist (symbol '(uia-term-phrase-memoized blue-fetch-uia-blue-event
                  bbf-rtv-all-edges-from-node
                  bbf-min-forward-and-backward-true bbf-rtv-all-edges-between
                  bbf-all-edges-subsumed-by-preds bbf-forward-true
                  bbf-backward-true bbf-min-forward-true bbf-min-backward-true
                  bbf-min-ceilings-forward-true bbf-script
                  bff-eeld-irrelevant-terms bff-cyc-kb-subset-collections
                  bff-arbitrary-unions bff-most-general-5 bff-most-general-10
                  bff-most-general-20))
  (register-api-predefined-function symbol))

;; Batch 4 — $list140
(dolist (symbol '(get-query-library-in-xml-from-default-mt
                  get-one-level-query-library-in-xml-from-default-mt
                  get-original-string-for-query parsed-query-template-p
                  clear-inverted-index index-queries-from-node
                  add-template-with-formula-and-gloss
                  suggest-loading-mt-for-cycl-query
                  create-minimal-formula-template-with-query
                  create-new-formula-template-with-query
                  get-variable-mappings-for-queries-in-xml
                  get-variable-mappings-for-formulas-in-xml
                  join-formulas-along-variable-mappings
                  join-queries-along-variable-mappings mail-to-user
                  mail-to-user-with-content-type
                  applicable-template-topics-for-term
                  focal-term-type-for-topic-type wff?))
  (register-api-predefined-function symbol))

;; Batch 5 — $list141
(dolist (symbol '(pph-inference-answer-proofs gke-start-continuable-query
                  gke-continue-query gke-stop-continuable-query
                  gke-get-inference-results gke-get-one-inference-result
                  gke-get-inference-status gke-get-inference-suspend-status
                  gke-inference-complete? gke-release-inference-resources
                  inference-answer-minimal-abduction-count))
  (register-api-predefined-function symbol))

;; Batch 6 — $list142
(dolist (symbol '(generate-phrase-for-java get-term-list-as-renderings
                  get-example-instances-as-renderings
                  get-example-instances-as-renderings-new
                  get-instances-as-renderings denots-of-string))
  (register-api-predefined-function symbol))

;; Batch 7 — $list143
(dolist (symbol '(reformulate-unknown-fet-term
                  clear-get-source-conceptual-works-for-project
                  get-source-conceptual-works-for-project
                  get-template-topic-in-xml
                  find-template-topic-matches-for-constraint
                  get-template-topic-assertions-for-match-in-xml))
  (register-api-predefined-function symbol))

;; Batch 8 — $list144
(dolist (symbol '(constant-via-star-completion delete-if el-negate relation-p
                  all-relation-constraint-sentences))
  (register-api-predefined-function symbol))

;; Batch 9 — $list145
(dolist (symbol '(add-template-with-formula-and-gloss answer-gui-question
                  clear-inverted-index find-inference-by-id
                  find-problem-store-by-id flatten get-original-string-for-query
                  index-queries-from-node indexed-queries-from-string
                  inference-input-el-query nart-substitute parsed-query-template-p
                  positive-infinity predicate-p remove-if-not
                  sksi-supported-external-term?))
  (register-api-predefined-function symbol))

;; Batch 10 — $list146
(dolist (symbol '(add-external-kb-modification-event-filter-listener alist-enter
                  answer-gui-question
                  augmented-query-string-for-cycl-terms
                  create-external-kb-modification-event-filter-listener
                  create-kb-modification-event-filter cyclist-notes
                  delete-external-kb-modification-event-filter-listener
                  delete-kb-modification-event-filter
                  explanation-of-why-not-wff explanation-of-why-not-wff-ask
                  find-assertion-cycl find-constant-by-guid
                  find-inference-answer-by-ids find-valid-fet-topic
                  ged-to-xml-string get-followups-for-entity
                  get-passages-for-entity hlmt-monad-mt hlmt-temporal-mt
                  html-var-value identify-all-geq-entities
                  make-induced-topic-type-for-term
                  mysentient-are-versions-supported?
                  pph-inference-answer-justification-for-java pph-proof-depth
                  pph-summarize-term proof-suid register-cyclify-parser
                  remove-external-kb-modification-event-filter-listener
                  return-document-as-string sentencify-remotely
                  template-type-for-focal-term-type topics-related-to-entity
                  wff-query?))
  (register-api-predefined-function symbol))

;; Predefined macros — $list147
(dolist (symbol '(with-paraphrase-mappings within-assert))
  (register-api-predefined-macro symbol))

;; Mutable globals — $list148
(dolist (symbol '(*cb-assertion-history* *cb-constant-history* *cb-nat-history*
                  *cb-sentence-history* *paraphrase-precision* *pph-addressee*
                  *pph-demerit-cutoff* *pph-domain-mt* *pph-language-mt*
                  *pph-link-arg0?* *pph-maximize-links?*
                  *pph-replace-bulleted-list-tags?* *pph-speaker*
                  *pph-suggested-demerit-cutoff* *pph-terse-mt-scope?*
                  *pph-use-bulleted-lists?* *pph-use-indexical-dates?*
                  *pph-use-smart-variable-replacement?*
                  *pph-use-title-capitalization?*))
  (register-api-mutable-global symbol))

;; External symbol
(register-external-symbol '<>)

;; Batch 11 — $list150
(dolist (symbol '(fi-create-skolem fi-merge fi-reassert fi-justify
                  fi-denotation fi-timestamp-constant fi-timestamp-assertion))
  (register-api-predefined-function symbol))

;; Host access functions from *api-host-access-functions*
(dolist (symbol *api-host-access-functions*)
  (register-api-predefined-host-function symbol))

;; More individual predefined functions
(register-api-predefined-function 'phrase-for-mt)
(register-api-predefined-function 'best-string-of-nl-phrase-defn)
(register-api-predefined-function 'cyc-1-byte-integer)
(register-api-predefined-function 'cyc-2-byte-integer)
(register-api-predefined-function 'cyc-4-byte-integer)
(register-api-predefined-function 'cyc-8-byte-integer)
(register-api-predefined-function 'cyc-absolute-value)
(register-api-predefined-function 'cyc-add-english-suffix)
(register-api-predefined-function 'cyc-arc-cosecant)
(register-api-predefined-function 'cyc-arc-cosine)
(register-api-predefined-function 'cyc-arc-cotangent)
(register-api-predefined-function 'cyc-arc-secant)
(register-api-predefined-function 'cyc-arc-sine)
(register-api-predefined-function 'cyc-arc-tangent)
(register-api-predefined-function 'cyc-ascii-string-p)
(register-api-predefined-function 'cyc-average)
(register-api-predefined-function 'cyc-bit-datatype)
(register-api-predefined-function 'cyc-collection-denoting-unary-function-for)
(register-api-predefined-function 'cyc-cosecant)
(register-api-predefined-function 'cyc-cosine)
(register-api-predefined-function 'cyc-cotangent)
(register-api-predefined-function 'cyc-date-after)
(register-api-predefined-function 'cyc-date-before)
(register-api-predefined-function 'cyc-date-decode-string)
(register-api-predefined-function 'cyc-date-encode-string)
(register-api-predefined-function 'cyc-date-from-integer)
(register-api-predefined-function 'cyc-date-from-string)
(register-api-predefined-function 'cyc-date-subsumes)
(register-api-predefined-function 'cyc-day-of-date)
(register-api-predefined-function 'cyc-day-of-week-after-date)
(register-api-predefined-function 'cyc-day-of-week-after-date-inclusive)
(register-api-predefined-function 'cyc-day-of-week-defn)
(register-api-predefined-function 'cyc-day-of-week-of-date)
(register-api-predefined-function 'cyc-day-of-week-prior-to-date)
(register-api-predefined-function 'cyc-day-of-week-prior-to-date-inclusive)
(register-api-predefined-function 'cyc-difference)
(register-api-predefined-function 'cyc-different)
(register-api-predefined-function 'cyc-different-symbols)
(register-api-predefined-function 'cyc-evaluate-subl)
(register-api-predefined-function 'cyc-even-number)
(register-api-predefined-function 'cyc-exp)
(register-api-predefined-function 'cyc-exponent)
(register-api-predefined-function 'cyc-extended-number-p)
(register-api-predefined-function 'cyc-greater-than)
(register-api-predefined-function 'cyc-greater-than-or-equal-to)
(register-api-predefined-function 'cyc-ground-term)
(register-api-predefined-function 'cyc-guid-string-p)
(register-api-predefined-function 'cyc-http-url-encode)
(register-api-predefined-function 'cyc-identity)
(register-api-predefined-function 'cyc-indexical-referent)
(register-api-predefined-function 'cyc-individual-denoting-unary-function-for)
(register-api-predefined-function 'cyc-individual-necessary)
(register-api-predefined-function 'cyc-integer)
(register-api-predefined-function 'cyc-integer-range)
(register-api-predefined-function 'cyc-integer-range) ;; duplicate in Java
(register-api-predefined-function 'cyc-integer-to-string)
(register-api-predefined-function 'cyc-interval-ended-by-last-subinterval-of-type)
(register-api-predefined-function 'cyc-interval-started-by-first-subinterval-of-type)
(register-api-predefined-function 'cyc-inverse)
(register-api-predefined-function 'cyc-ip4-address)
(register-api-predefined-function 'cyc-ip4-network-address)
(register-api-predefined-function 'cyc-later-than)
(register-api-predefined-function 'cyc-less-than)
(register-api-predefined-function 'cyc-less-than-or-equal-to)
(register-api-predefined-function 'cyc-list-concatenate)
(register-api-predefined-function 'cyc-list-first)
(register-api-predefined-function 'cyc-list-last)
(register-api-predefined-function 'cyc-list-length)
(register-api-predefined-function 'cyc-list-member-set)
(register-api-predefined-function 'cyc-list-nth)
(register-api-predefined-function 'cyc-list-of-type-necessary)
(register-api-predefined-function 'cyc-list-of-type-sufficient)
(register-api-predefined-function 'cyc-list-rest)
(register-api-predefined-function 'cyc-list-reverse)
(register-api-predefined-function 'cyc-list-search)
(register-api-predefined-function 'cyc-list-subseq)
(register-api-predefined-function 'cyc-list-without-repetition)
(register-api-predefined-function 'cyc-log)
(register-api-predefined-function 'cyc-logarithm)
(register-api-predefined-function 'cyc-make-formula)
(register-api-predefined-function 'cyc-map-function-over-list)
(register-api-predefined-function 'cyc-max-range)
(register-api-predefined-function 'cyc-maximum)
(register-api-predefined-function 'cyc-min-range)
(register-api-predefined-function 'cyc-minimum)
(register-api-predefined-function 'cyc-minus)
(register-api-predefined-function 'cyc-negative-integer)
(register-api-predefined-function 'cyc-negative-number)
(register-api-predefined-function 'cyc-next-iterated-cyclic-interval)
(register-api-predefined-function 'cyc-non-negative-integer)
(register-api-predefined-function 'cyc-non-negative-number)
(register-api-predefined-function 'cyc-non-positive-integer)
(register-api-predefined-function 'cyc-non-positive-number)
(register-api-predefined-function 'cyc-nth-metrically-preceding-time-interval-of-type)
(register-api-predefined-function 'cyc-nth-metrically-succeeding-time-interval-of-type)
(register-api-predefined-function 'cyc-number-string)
(register-api-predefined-function 'cyc-numeral-string)
(register-api-predefined-function 'cyc-numeric-string-necessary)
(register-api-predefined-function 'cyc-numerically-equal)
(register-api-predefined-function 'cyc-odd-number)
(register-api-predefined-function 'cyc-percent)
(register-api-predefined-function 'cyc-plus)
(register-api-predefined-function 'cyc-plus-all)
(register-api-predefined-function 'cyc-position)
(register-api-predefined-function 'cyc-positive-integer)
(register-api-predefined-function 'cyc-positive-number)
(register-api-predefined-function 'cyc-post-remove)
(register-api-predefined-function 'cyc-pre-remove)
(register-api-predefined-function 'cyc-prefix-substring)
(register-api-predefined-function 'cyc-prime-number?)
(register-api-predefined-function 'cyc-quantity-conversion)
(register-api-predefined-function 'cyc-quantity-intersects)
(register-api-predefined-function 'cyc-quantity-subsumes)
(register-api-predefined-function 'cyc-quotient)
(register-api-predefined-function 'cyc-rational-number)
(register-api-predefined-function 'cyc-real-0-1)
(register-api-predefined-function 'cyc-real-1-infinity)
(register-api-predefined-function 'cyc-real-number)
(register-api-predefined-function 'cyc-recapitalize-smart)
(register-api-predefined-function 'cyc-relation-arg)
(register-api-predefined-function 'cyc-relation-arg-set)
(register-api-predefined-function 'cyc-relation-args-list)
(register-api-predefined-function 'cyc-relation-expression-arity)
(register-api-predefined-function 'cyc-replace-substring)
(register-api-predefined-function 'cyc-round-closest)
(register-api-predefined-function 'cyc-round-down)
(register-api-predefined-function 'cyc-round-up)
(register-api-predefined-function 'cyc-scientific-number-from-string)
(register-api-predefined-function 'cyc-scientific-number-from-subl-real)
(register-api-predefined-function 'cyc-scientific-number-p)
(register-api-predefined-function 'cyc-scientific-number-significant-digit-count)
(register-api-predefined-function 'cyc-scientific-number-to-string)
(register-api-predefined-function 'cyc-scientific-number-to-subl-real)
(register-api-predefined-function 'cyc-secant)
(register-api-predefined-function 'cyc-set-difference)
(register-api-predefined-function 'cyc-set-extent)
(register-api-predefined-function 'cyc-set-of-type-necessary)
(register-api-predefined-function 'cyc-set-of-type-sufficient)
(register-api-predefined-function 'cyc-significant-digits)
(register-api-predefined-function 'cyc-sine)
(register-api-predefined-function 'cyc-sksi-source-accessible)
(register-api-predefined-function 'cyc-sksi-source-activated)
(register-api-predefined-function 'cyc-sksi-source-queryable)
(register-api-predefined-function 'cyc-sksi-source-registered)
(register-api-predefined-function 'cyc-sqrt)
(register-api-predefined-function 'cyc-string-concat)
(register-api-predefined-function 'cyc-string-to-integer)
(register-api-predefined-function 'cyc-string-to-real-number)
(register-api-predefined-function 'cyc-string-tokenize-new)
(register-api-predefined-function 'cyc-string-upcase)
(register-api-predefined-function 'cyc-strings-to-phrase)
(register-api-predefined-function 'cyc-subl-escape)
(register-api-predefined-function 'cyc-subl-expression)
(register-api-predefined-function 'cyc-subl-template)
(register-api-predefined-function 'cyc-sublist?)
(register-api-predefined-function 'cyc-substitute-formula)
(register-api-predefined-function 'cyc-substitute-formula-arg)
(register-api-predefined-function 'cyc-substitute-formula-arg-position)
(register-api-predefined-function 'cyc-substring)
(register-api-predefined-function 'cyc-substring-case-insensitive-predicate)
(register-api-predefined-function 'cyc-substring-predicate)
(register-api-predefined-function 'cyc-subword-predicate)
(register-api-predefined-function 'cyc-suffix-substring)
(register-api-predefined-function 'cyc-system-atom)
(register-api-predefined-function 'cyc-system-character-p)
(register-api-predefined-function 'cyc-system-integer)
(register-api-predefined-function 'cyc-system-non-variable-symbol-p)
(register-api-predefined-function 'cyc-system-real-number-p)
(register-api-predefined-function 'cyc-system-string-p)
(register-api-predefined-function 'cyc-system-term-p)
(register-api-predefined-function 'cyc-tangent)
(register-api-predefined-function 'cyc-time-elapsed)
(register-api-predefined-function 'cyc-time-elapsed-decode-string)
(register-api-predefined-function 'cyc-time-elapsed-encode-string)
(register-api-predefined-function 'cyc-times)
(register-api-predefined-function 'cyc-trim-whitespace)
(register-api-predefined-function 'cyc-true-subl)
(register-api-predefined-function 'cyc-types-most-often-asserted-using-tool)
(register-api-predefined-function 'cyc-unicode-denoting-ascii-string-p)
(register-api-predefined-function 'cyc-zip-code-five-digit)
(register-api-predefined-function 'cyc-zip-code-nine-digit)
(register-api-predefined-function 'cycl-asserted-assertion?)
(register-api-predefined-function 'cycl-assertion?)
(register-api-predefined-function 'cycl-atomic-assertion?)
(register-api-predefined-function 'cycl-atomic-sentence?)
(register-api-predefined-function 'cycl-atomic-term-p)
(register-api-predefined-function 'cycl-closed-atomic-sentence?)
(register-api-predefined-function 'cycl-closed-atomic-term-p)
(register-api-predefined-function 'cycl-closed-denotational-term?)
(register-api-predefined-function 'cycl-closed-expression?)
(register-api-predefined-function 'cycl-closed-formula?)
(register-api-predefined-function 'cycl-closed-non-atomic-term?)
(register-api-predefined-function 'cycl-closed-sentence?)
(register-api-predefined-function 'cycl-constant-p)
(register-api-predefined-function 'cycl-deduced-assertion?)
(register-api-predefined-function 'cycl-denotational-term-p)
(register-api-predefined-function 'cycl-expression-askable?)
(register-api-predefined-function 'cycl-expression-assertible?)
(register-api-predefined-function 'cycl-expression?)
(register-api-predefined-function 'cycl-formula?)
(register-api-predefined-function 'cycl-gaf-assertion?)
(register-api-predefined-function 'cycl-indexed-term?)
(register-api-predefined-function 'cycl-nl-semantic-assertion?)
(register-api-predefined-function 'cycl-non-atomic-reified-term?)
(register-api-predefined-function 'cycl-non-atomic-term-askable?)
(register-api-predefined-function 'cycl-non-atomic-term-assertible?)
(register-api-predefined-function 'cycl-non-atomic-term?)
(register-api-predefined-function 'cycl-open-denotational-term?)
(register-api-predefined-function 'cycl-open-expression?)
(register-api-predefined-function 'cycl-open-formula?)
(register-api-predefined-function 'cycl-open-non-atomic-term?)
(register-api-predefined-function 'cycl-open-sentence?)
(register-api-predefined-function 'cycl-propositional-sentence?)
(register-api-predefined-function 'cycl-reformulator-rule?)
(register-api-predefined-function 'cycl-reifiable-denotational-term?)
(register-api-predefined-function 'cycl-reifiable-non-atomic-term?)
(register-api-predefined-function 'cycl-reified-denotational-term?)
(register-api-predefined-function 'cycl-represented-atomic-term-p)
(register-api-predefined-function 'cycl-represented-term?)
(register-api-predefined-function 'cycl-rule-assertion?)
(register-api-predefined-function 'cycl-sentence-askable?)
(register-api-predefined-function 'cycl-sentence-assertible?)
(register-api-predefined-function 'cycl-sentence?)
(register-api-predefined-function 'cycl-subl-symbol-p)
(register-api-predefined-function 'cycl-unbound-relation-formula-p)
(register-api-predefined-function 'cycl-var-list?)
(register-api-predefined-function 'cycl-variable-p)
(register-api-predefined-function 'cycsecure-sub-software-objects?)
(register-api-predefined-function 'cycsecure-version-of-software?)
(register-api-predefined-function 'gaf?)
(register-api-predefined-function 'gen-template-recipe-p)
(register-api-predefined-function 'generate-names-for-term)
(register-api-predefined-function 'generate-phrase-defn)
(register-api-predefined-function 'hl-external-id-string-p)
(register-api-predefined-function 'ibqe?)
(register-api-predefined-function 'integerp)
(register-api-predefined-function 'keywordp)
(register-api-predefined-function 'kwte?)
(register-api-predefined-function 'listp)
(register-api-predefined-function 'monad-cycl-mt?)
(register-api-predefined-function 'non-negative-scalar-interval?)
(register-api-predefined-function 'positive-scalar-interval?)
(register-api-predefined-function 'pre-remove-definite-article-from-string)
(register-api-predefined-function 'rtp-syntactic-constraint)
(register-api-predefined-function 'scalar-point-value?)
(register-api-predefined-function 'string-w/o-control-chars?)
(register-api-predefined-function 'stringp)
(register-api-predefined-function 'subl-non-variable-non-keyword-symbol-p)
(register-api-predefined-function 'symbolp)
(register-api-predefined-function 'temporal-dimension-mt-p)
(register-api-predefined-function 'true)
(register-api-predefined-function 'url-p)

;; Batch 12 — $list403
(dolist (symbol '(new-cyc-query nth-value inference-all-answers
                  inference-answer-justifications
                  inference-answer-justification-supports hl-justify
                  hl-justify-expanded))
  (register-api-predefined-function symbol))
