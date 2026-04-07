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

;; FOLification — conversion of Cyc KB content to First-Order Logic representations.
;; All functions in this file were stripped from the LarKC release.

(deflexical *folification-version* "0.7.2")

(defparameter *fol-translation-type* :regular-fol
  "[Cyc] One of :regular-fol
        :set-theory")

(defparameter *fol-mt-handling* :mt-visible-except-core-mts
  "[Cyc] One of :mt-visible
        :mt-visible-except-core-mts
	:mt-argument
        (:collapse <single-theory>)
        :flat (not recommended)")

(defparameter *fol-isa-handling* :unary-predicate
  "[Cyc] One of :unary-predicate, :isa")

(defparameter *fol-rmp-handling* :gaf
  "[Cyc] How to handle rule macro predicates:
 One of :gaf, :expansion, :gaf-and-expansion")

(defparameter *fol-string-handling* :allowed
  "[Cyc] One of :allowed, :dwim-to-single-constant, :dwim-to-distinct-constants, :skip")

(defparameter *fol-number-handling* :dwim-floats-to-distinct-constants
  "[Cyc] One of :allowed, :dwim-floats-to-distinct-constants, :dwim-all-to-distinct-constants")

(deflexical *unfolifiable-terms*
    (list (reader-make-constant-shell "Quote")
          (reader-make-constant-shell "EscapeQuote")
          (reader-make-constant-shell "QuasiQuote")
          (reader-make-constant-shell "SubLQuoteFn")
          (reader-make-constant-shell "ExpandSubLFn")
          (reader-make-constant-shell "completeExtentEnumerable")
          (reader-make-constant-shell "completelyEnumerableCollection")
          (reader-make-constant-shell "unknownSentence")
          (reader-make-constant-shell "evaluate")
          (reader-make-constant-shell "Nothing")
          (reader-make-constant-shell "CollectionDifferenceFn")
          (reader-make-constant-shell "reformulatorEquiv"))
  "[Cyc] Terms that are explicitly forbidden to be converted to FOL.")

(deflexical *folification-unhandled-explanation-table*
    (list :variable-arity-predicate "contained a variable-arity predicate with a maximum arity."
          :variable-arity-function "contained a variable-arity function with a maximum arity."
          :unbounded-arity-predicate "contained a variable-arity predicate with an unbounded arity."
          :unbounded-arity-function "contained a variable-arity function with an unbounded arity."
          :meta-sentence "contained an embedded sentence used as a term."
          :meta-assertion "contained an embedded assertion used as a term."
          :meta-variable "contained a meta-variable."
          :subl-escape "contained an escape to SubL (a hook into the underlying implentation language)"
          :function-arg-constraint "expressed an argument constraint on a function, for which there is currently no FOL translation."
          :function-quantification "quantified over functions."
          :predicate-quantification "quantified over predicates."
          :collection-quantification "quantified into a collection, which is like quantifying over predicates."
          :sequence-var "contained a sequence variable"
          :ist "used the predicate #$ist, which is used to do quantification across contexts or contextual lifting."
          :ill-formed "were ill-formed.  This illustrates a problem with the Cyc KB itself, not with the Cyc -> FOL conversion."
          :nonstandard-sentential-relation "contained a bounded existential, or a user-defined logical operator or quantifier"
          :expansion "had an expansion that could not be translated"
          :kappa "contained Kappa, a predicate-denoting function"
          :lambda "contained Lambda, a function-denoting function"
          :explicitly-forbidden-term "contained an explicitly forbidden term, function, or predicate")
  "[Cyc] COUNT assertion(s) could not be converted to FOL because it/they...")

(deflexical *fol-output-formats* (list :tptp :cycl)
  "[Cyc] The list of possible FOL output formats")

(defparameter *tptp-query-name* nil
  "[Cyc] If non-nil, will use this name for the conjecture instead of a number.")

(defparameter *tptp-axiom-prefix* nil
  "[Cyc] If non-nil, will prefix all axiom ids with this string.")

(defparameter *tptp-axiom-count* nil)
(defparameter *candidate-sentence-count* nil)
(defparameter *handled-sentence-count* nil)
(defparameter *term-count* nil)
(defparameter *handled-term-count* nil)
(defparameter *partially-handled-term-count* nil)
(defparameter *unhandled-term-count* nil)

(defparameter *fol-current-assertion* nil
  "[Cyc] This is only used to handle HL variables in assertion objects.")

(deflexical *fol-sequence-variable-args-for-arity-caching-state* nil)
(deflexical *compute-tptp-query-index-number-caching-state* nil)

(deflexical *tptp-long-symbol-name-cache*
    (if (and (boundp '*tptp-long-symbol-name-cache*)
             (typep *tptp-long-symbol-name-cache* 'hash-table))
        *tptp-long-symbol-name-cache*
        (make-hash-table :test #'equal :size 256)))

(defparameter *tptp-long-symbol-min-length* 256
  "[Cyc] The minimum length that a symbol must be to be considered too long")

(defparameter *categorize-fol-predicates* nil)
(defparameter *categorize-fol-functions* nil)
(defparameter *categorize-fol-terms* nil)
(deflexical *fol-nart-string-caching-state* nil)

(deflexical *deepak-folification-properties*
    (list :translation-type :set-theory
          :mt-handling :mt-visible-except-core-mts
          :isa-handling :unary-predicate
          :string-handling :dwim-to-single-constant))

(deflexical *deepak-queries*
    (list (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "CurrentWorldDataCollectorMt-NonHomocentric")
                (list (reader-make-constant-shell "isa")
                      (reader-make-constant-shell "isa")
                      (reader-make-constant-shell "Individual")))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "CurrentWorldDataCollectorMt-NonHomocentric")
                (list (reader-make-constant-shell "implies")
                      (list (reader-make-constant-shell "and")
                            (list (reader-make-constant-shell "subOrganizations") '?z '?x)
                            (list (reader-make-constant-shell "hasMembers") '?x '?y))
                      (list (reader-make-constant-shell "hasMembers") '?z '?y)))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "CurrentWorldDataCollectorMt-NonHomocentric")
                (list (reader-make-constant-shell "typePrimaryFunction")
                      (reader-make-constant-shell "Bathtub")
                      (reader-make-constant-shell "TakingABath")
                      (reader-make-constant-shell "deviceUsed")))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "CurrentWorldDataCollectorMt-NonHomocentric")
                (list (reader-make-constant-shell "typeBehaviorIncapable")
                      (reader-make-constant-shell "Doughnut")
                      (reader-make-constant-shell "Talking")
                      (reader-make-constant-shell "doneBy")))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "CurrentWorldDataCollectorMt-NonHomocentric")
                (list (reader-make-constant-shell "implies")
                      (list (reader-make-constant-shell "and")
                            (list (reader-make-constant-shell "parts") '?x '?y)
                            (list (reader-make-constant-shell "parts") '?y '?z))
                      (list (reader-make-constant-shell "parts") '?x '?z)))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "CurrentWorldDataCollectorMt-NonHomocentric")
                (list (reader-make-constant-shell "disjointWith")
                      (reader-make-constant-shell "Baseball-Ball")
                      (reader-make-constant-shell "Cube")))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "CurrentWorldDataCollectorMt-NonHomocentric")
                (list (reader-make-constant-shell "disjointWith")
                      (reader-make-constant-shell "HumanInfant")
                      (reader-make-constant-shell "Doctor-Medical")))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "TerrestrialFrameOfReferenceMt")
                (list (reader-make-constant-shell "implies")
                      (list (reader-make-constant-shell "and")
                            (list (reader-make-constant-shell "isa") '?cup (reader-make-constant-shell "CoffeeCup"))
                            (list (reader-make-constant-shell "isa") '?coffee (reader-make-constant-shell "Coffee-Hot"))
                            (list (reader-make-constant-shell "in-ContOpen") '?coffee '?cup))
                      (list (reader-make-constant-shell "orientation") '?cup (reader-make-constant-shell "RightSideUp")))))
  "[Cyc] Queries used in the first FOLification paper: First-Orderized ResearchCyc : Expressivity and Efficiency in a Common-Sense Ontology")

(deflexical *deepak-queries-2*
    (list (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "BaseKB")
                (list (reader-make-constant-shell "isa")
                      (reader-make-constant-shell "isa")
                      (reader-make-constant-shell "Individual")))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "BaseKB")
                (list (reader-make-constant-shell "disjointWith")
                      (reader-make-constant-shell "Baseball-Ball")
                      (reader-make-constant-shell "Cube")))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "ProductUsageMt")
                (list (reader-make-constant-shell "typePrimaryFunction")
                      (reader-make-constant-shell "Bathtub")
                      (reader-make-constant-shell "TakingABath")
                      (reader-make-constant-shell "deviceUsed")))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "AnimalActivitiesMt")
                (list (reader-make-constant-shell "typeBehaviorIncapable")
                      (reader-make-constant-shell "InanimateObject")
                      (reader-make-constant-shell "AtLeastPartiallyMentalEvent")
                      (reader-make-constant-shell "doneBy")))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "UnitedStatesSocialLifeMt")
                (list (reader-make-constant-shell "genls")
                      (reader-make-constant-shell "HumanInfant")
                      (reader-make-constant-shell "HumanPreSchoolageChild")))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "IndustryMt")
                (list (reader-make-constant-shell "implies")
                      (list (reader-make-constant-shell "and")
                            (list (reader-make-constant-shell "subOrganizations") '?z '?x)
                            (list (reader-make-constant-shell "hasMembers") '?x '?y))
                      (list (reader-make-constant-shell "hasMembers") '?z '?y)))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "ClothingGMt")
                (list (reader-make-constant-shell "thereExists") '?x
                      (list (reader-make-constant-shell "and")
                            (list (reader-make-constant-shell "isa") '?x (reader-make-constant-shell "Garment"))
                            (list (reader-make-constant-shell "isa") '?x (reader-make-constant-shell "Bluish")))))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "WorldCulturalGeographyDataMt")
                (list (reader-make-constant-shell "implies")
                      (list (reader-make-constant-shell "perpetrator")
                            (reader-make-constant-shell "BombingOfIraqEvent")
                            (reader-make-constant-shell "UnitedStatesOfAmerica"))
                      (list (reader-make-constant-shell "thereExists") '?y
                            (list (reader-make-constant-shell "and")
                                  (list (reader-make-constant-shell "isa") '?y (reader-make-constant-shell "Person"))
                                  (list (reader-make-constant-shell "responsibleFor") '?y (reader-make-constant-shell "BombingOfIraqEvent"))))))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "UniversalVocabularyMt")
                (list (reader-make-constant-shell "disjointWith")
                      (reader-make-constant-shell "BlowDryer")
                      (reader-make-constant-shell "Weapon")))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "UniversalVocabularyMt")
                (list (reader-make-constant-shell "implies")
                      (list (reader-make-constant-shell "isa") '?x (reader-make-constant-shell "GolfCart"))
                      (list (reader-make-constant-shell "not")
                            (list (reader-make-constant-shell "isa") '?x (reader-make-constant-shell "ArmoredVehicle")))))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "UniversalVocabularyMt")
                (list (reader-make-constant-shell "or")
                      (list (reader-make-constant-shell "isa") (reader-make-constant-shell "Alice") (reader-make-constant-shell "Animal"))
                      (list (reader-make-constant-shell "isa") (reader-make-constant-shell "Alice") (reader-make-constant-shell "Vegetable-Plant"))
                      (list (reader-make-constant-shell "isa") (reader-make-constant-shell "Alice") (reader-make-constant-shell "Mineral"))))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "ArtifactGVocabularyMt")
                (list (reader-make-constant-shell "implies")
                      (list (reader-make-constant-shell "isa") '?x (reader-make-constant-shell "FireplacePoker"))
                      (list (reader-make-constant-shell "thereExists") '?y
                            (list (reader-make-constant-shell "and")
                                  (list (reader-make-constant-shell "productTypeManufacturedIn")
                                        '?x (reader-make-constant-shell "Foundry-Building"))))))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "UniversalVocabularyMt")
                (list (reader-make-constant-shell "implies")
                      (list (reader-make-constant-shell "and")
                            (list (reader-make-constant-shell "parts") '?x '?y)
                            (list (reader-make-constant-shell "parts") '?y '?z))
                      (list (reader-make-constant-shell "parts") '?x '?z)))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "UniversalVocabularyMt")
                (list (reader-make-constant-shell "implies")
                      (list (reader-make-constant-shell "covers-Generic") '?x '?y)
                      (list (reader-make-constant-shell "not")
                            (list (reader-make-constant-shell "transformedInto") '?y '?x))))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "UniversalVocabularyMt")
                (list (reader-make-constant-shell "interArgIsa2-1")
                      (reader-make-constant-shell "anatomicalParts")
                      (list (reader-make-constant-shell "FruitFn")
                            (reader-make-constant-shell "BananaTree"))
                      (reader-make-constant-shell "BananaTree")))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "UniversalVocabularyMt")
                (list (reader-make-constant-shell "not")
                      (list (reader-make-constant-shell "thereExists") '?x
                            (list (reader-make-constant-shell "thereExists") '?y
                                  (list (reader-make-constant-shell "and")
                                        (list (reader-make-constant-shell "performedBy") '?x '?y)
                                        (list (reader-make-constant-shell "isa") '?x (reader-make-constant-shell "ArrestingSomeone"))
                                        (list (reader-make-constant-shell "isa") '?y (reader-make-constant-shell "PrivateSectorEmployee")))))))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "UniversalVocabularyMt")
                (list (reader-make-constant-shell "implies")
                      (list (reader-make-constant-shell "and")
                            (list (reader-make-constant-shell "isa") '?x (reader-make-constant-shell "Thinking"))
                            (list (reader-make-constant-shell "doneBy") '?x '?y))
                      (list (reader-make-constant-shell "isa") '?y (reader-make-constant-shell "SomethingExisting"))))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "CIAWorldFactbook1997Mt")
                (list (reader-make-constant-shell "not")
                      (list (reader-make-constant-shell "permanentMemberOfOrganization")
                            (reader-make-constant-shell "SouthKorea")
                            (reader-make-constant-shell "UNSecurityCouncil"))))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "UniversalVocabularyMt")
                (list (reader-make-constant-shell "implies")
                      (list (reader-make-constant-shell "and")
                            (list (reader-make-constant-shell "isa") '?x (reader-make-constant-shell "ScatteredSpaceRegion"))
                            (list (reader-make-constant-shell "convexSpaceRegionOf") '?y '?x)
                            (list (reader-make-constant-shell "thereExists") '?z
                                  (list (reader-make-constant-shell "convexSpaceRegionOf") '?x '?z)))
                      (list (reader-make-constant-shell "componentPartOfSpaceRegion") '?y '?x)))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "ProductPhysicalCharacteristicsMt")
                (list (reader-make-constant-shell "implies")
                      (list (reader-make-constant-shell "and")
                            (list (reader-make-constant-shell "isa") '?x (reader-make-constant-shell "PhoneAnsweringMachineCombo"))
                            (list (reader-make-constant-shell "uniformColorOfObject") '?x '?y)
                            (list (reader-make-constant-shell "isa") '?z (reader-make-constant-shell "ResetButton"))
                            (list (reader-make-constant-shell "surfaceParts") '?z '?x))
                      (list (reader-make-constant-shell "uniformColorOfObject") '?z '?y)))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "PatternsOfGlobalTerrorism1998Mt")
                (list (reader-make-constant-shell "implies")
                      (list (reader-make-constant-shell "and")
                            (list (reader-make-constant-shell "isa") '?comp2 (reader-make-constant-shell "IBMNetfinityComputer"))
                            (list (reader-make-constant-shell "isa") '?comp1 (reader-make-constant-shell "SunMachine"))
                            (list (reader-make-constant-shell "equivalentHosts") '?comp1 '?comp2)
                            (list (reader-make-constant-shell "doneBy") '?crack '?hacker)
                            (list (reader-make-constant-shell "isa") '?crack (reader-make-constant-shell "Cracking-CompromisingSecurity"))
                            (list (reader-make-constant-shell "securityCompromised") '?crack '?comp1))
                      (list (reader-make-constant-shell "thereExists") '?action
                            (list (reader-make-constant-shell "damages") '?action '?comp2))))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "NaiveInformationMt")
                (list (reader-make-constant-shell "implies")
                      (list (reader-make-constant-shell "and")
                            (list (reader-make-constant-shell "isa") '?cup (reader-make-constant-shell "Demitasse"))
                            (list (reader-make-constant-shell "isa") '?coffee (reader-make-constant-shell "Coffee-Hot"))
                            (list (reader-make-constant-shell "in-ContOpen") '?coffee '?cup))
                      (list (reader-make-constant-shell "orientation") '?cup (reader-make-constant-shell "RightSideUp"))))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "CurrentWorldDataCollectorMt-NonHomocentric")
                (list (reader-make-constant-shell "typeBehaviorIncapable")
                      (reader-make-constant-shell "Can")
                      (reader-make-constant-shell "Cancan-StyleOfDance")
                      (reader-make-constant-shell "performedBy")))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "CurrentWorldDataCollectorMt-NonHomocentric")
                (list (reader-make-constant-shell "not")
                      (list (reader-make-constant-shell "relationInstanceExists")
                            (reader-make-constant-shell "biologicalFather")
                            (reader-make-constant-shell "Cyc")
                            (reader-make-constant-shell "MaleAnimal"))))
          (list (reader-make-constant-shell "ist")
                (reader-make-constant-shell "TKBSourceSpindleCollectorMt")
                (list (reader-make-constant-shell "thereExists") '?terrorist
                      (list (reader-make-constant-shell "and")
                            (list (reader-make-constant-shell "isa") '?terrorist (reader-make-constant-shell "Terrorist"))
                            (list (reader-make-constant-shell "birthPlace") '?terrorist (reader-make-constant-shell "ContinentOfAsia"))))))
  "[Cyc] Queries used in the second FOLification paper")

;; Commented-out declareFunction entries. All function bodies were stripped from LarKC.

;; (defun fol-translation-type-property-p (object) ...) -- commented declareFunction, no body
;; (defun fol-mt-handling-property-p (object) ...) -- commented declareFunction, no body
;; (defun fol-isa-handling-property-p (object) ...) -- commented declareFunction, no body
;; (defun fol-rmp-handling-property-p (object) ...) -- commented declareFunction, no body
;; (defun fol-string-handling-property-p (object) ...) -- commented declareFunction, no body
;; (defun fol-number-handling-property-p (object) ...) -- commented declareFunction, no body
;; (defun fol-output-format-p (object) ...) -- commented declareFunction, no body
;; (defun new-fol-sentences-analysis (data gen-props rej-stats cand-count fol-count term-count handled-count partial-count unhandled-count) ...) -- commented declareFunction, no body
;; (defun fol-sentences-analysis-data (analysis) ...) -- commented declareFunction, no body
;; (defun fol-sentences-analysis-generation-properties (analysis) ...) -- commented declareFunction, no body
;; (defun fol-sentences-analysis-rejection-statistics (analysis) ...) -- commented declareFunction, no body
;; (defun kb-fol-sentences (&optional properties) ...) -- commented declareFunction, no body
;; (defun cycl-assertions-to-fol (assertions &optional properties mt) ...) -- commented declareFunction, no body
;; (defun cycl-sentences-to-fol (sentences &optional properties) ...) -- commented declareFunction, no body
;; (defun fol-sentences (input type properties &optional stream) ...) -- commented declareFunction, no body
;; (defun assertions-fol-sentences-data (assertions translation-type mt-handling mt-ceiling isa-handling rmp-handling string-handling number-handling allow-equiv?) ...) -- commented declareFunction, no body
;; (defun sentences-fol-sentences-data (sentences translation-type mt-handling mt-ceiling isa-handling rmp-handling string-handling number-handling allow-equiv?) ...) -- commented declareFunction, no body
;; (defun forts-fol-sentences-data (forts translation-type mt-handling mt-ceiling isa-handling rmp-handling string-handling number-handling allow-equiv?) ...) -- commented declareFunction, no body
;; (defun load-fol-sentences-analysis (filename) ...) -- commented declareFunction, no body
;; (defun fol-sentences-input-item-type (item) ...) -- commented declareFunction, no body
;; (defun fol-sentences-analysis-nmerge-fol-sentences-data (analysis data) ...) -- commented declareFunction, no body
;; (defun fol-sentences-to-file (analysis filename format) ...) -- commented declareFunction, no body
;; (defun fol-sentences-to-stream (analysis stream &optional format) ...) -- commented declareFunction, no body
;; (defun fol-sentences-symbol-count (analysis) ...) -- commented declareFunction, no body
;; (defun query-fol-sentence (sentence mt &optional properties) ...) -- commented declareFunction, no body
;; (defun fol-query-to-stream (sentence mt stream &optional properties) ...) -- commented declareFunction, no body
;; (defun kbq-fol-sentence (query-id &optional properties) ...) -- commented declareFunction, no body
;; (defun kbq-fol-sentence-to-stream (query-id mt stream &optional format properties) ...) -- commented declareFunction, no body
;; (defun assertion-fol-sentences-to-stream (assertion stream &optional format) ...) -- commented declareFunction, no body
;; (defun make-and-postprocess-fol-sentences-datum (term fol-sentences analysis include-comments? output-format stream) ...) -- commented declareFunction, no body
;; (defun make-fol-sentences-datum (term fol-sentences) ...) -- commented declareFunction, no body
;; (defun postprocess-fol-sentences-datum (datum analysis include-comments? output-format stream) ...) -- commented declareFunction, no body
;; (defun postprocess-fol-sentences-datum-output (datum output-format stream) ...) -- commented declareFunction, no body
;; (defun postprocess-fol-sentences-datum-analysis (datum analysis include-comments?) ...) -- commented declareFunction, no body
;; (defun possibly-save-fol-sentences-analysis (analysis filename) ...) -- commented declareFunction, no body
;; (defun update-fol-analysis-counts (analysis) ...) -- commented declareFunction, no body
;; (defun check-folification-properties (translation-type mt-handling mt-ceiling isa-handling rmp-handling string-handling number-handling allow-equiv? sample-rate output-filename output-format header analysis-filename analysis-file-internal? include-comments? return-data? negate-queries? verbose?) ...) -- commented declareFunction, no body
;; (defun kb-fol-assertion-under-mt-ceiling? (assertion mt-ceiling) ...) -- commented declareFunction, no body
;; (defun kb-fol-under-mt-ceiling? (mt mt-ceiling) ...) -- commented declareFunction, no body
;; (defun assertion-fol-sentences (assertion) ...) -- commented declareFunction, no body
;; (defun assertion-fol-sentences-int (assertion mt) ...) -- commented declareFunction, no body
;; (defun sentence-fol-sentences (sentence mt) ...) -- commented declareFunction, no body
;; (defun fol-expand-sentence (sentence mt) ...) -- commented declareFunction, no body
;; (defun fol-expandible-expression? (expression) ...) -- commented declareFunction, no body
;; (defun fol-expandible-rmp? (rmp) ...) -- commented declareFunction, no body
;; (defun fol-expand-one-step (expression &optional mt) ...) -- commented declareFunction, no body
;; (defun cnf-clausal-form-for-fol (cnf mt) ...) -- commented declareFunction, no body
;; (defun cnf-fol-sentences (cnf mt) ...) -- commented declareFunction, no body
;; (defun partition-fol-unhandled-sentences (sentences) ...) -- commented declareFunction, no body
;; (defun fol-sentences-datum-update-rejection-statistics (datum statistics) ...) -- commented declareFunction, no body
;; (defun update-fol-rejection-statistics-for-expression (expression statistics) ...) -- commented declareFunction, no body
;; (defun print-folification-summary (analysis &optional stream) ...) -- commented declareFunction, no body
;; (defun print-fol-rejection-statistics (statistics &optional stream) ...) -- commented declareFunction, no body
;; (defun pretty-print-fol-rejection-statistics (statistics &optional stream) ...) -- commented declareFunction, no body
;; (defun fol-unhandled-explanation (keyword) ...) -- commented declareFunction, no body
;; (defun fol-unhandled-expression-p (expression) ...) -- commented declareFunction, no body
;; (defun contains-fol-unhandled-expression-p (expression) ...) -- commented declareFunction, no body
;; (defun fol-unhandled (reason culprit) ...) -- commented declareFunction, no body
;; (defun additional-gaf-fol-sentences (gaf mt) ...) -- commented declareFunction, no body
;; (defun additional-arg-isa-or-arg-genl-sentences (gaf mt type) ...) -- commented declareFunction, no body
;; (defun additional-result-isa-or-result-genl-sentences (gaf mt type) ...) -- commented declareFunction, no body
;; (defun nonstandard-sentential-relation-p (relation) ...) -- commented declareFunction, no body
;; (defun clear-fol-sequence-variable-args-for-arity () ...) -- commented declareFunction, no body
;; (defun remove-fol-sequence-variable-args-for-arity (arity) ...) -- commented declareFunction, no body
;; (defun fol-sequence-variable-args-for-arity-internal (arity) ...) -- commented declareFunction, no body
;; (defun fol-sequence-variable-args-for-arity (arity) ...) -- commented declareFunction, no body
;; (defun kb-fol-additional-sentences-for-term (term mt type) ...) -- commented declareFunction, no body

;; Reconstructed from Internal Constants: $list171 (arglist), $sym172-$sym174 (gensyms),
;; $sym175 PWHEN, $sym176 FIXED-ARITY-PREDICATE-P, $sym177 CLET, $sym178 ARITY,
;; $sym179 CDOTIMES, $sym180 1+, $sym181 ARG-ISA-PRED, $sym182 DO-GAF-ARG-INDEX,
;; $kw183 :PREDICATE, $list184 (:INDEX 1 :TRUTH :TRUE).
;; This macro iterates over the argIsa GAFs for a predicate by computing its arity,
;; generating the argNIsa predicate for each arg position, then iterating over GAFs
;; indexed by that predicate.
(defmacro do-arg-isa-gafs ((gaf-var argnum-var pred) &body body)
  (with-temp-vars (argnum-1 arg-isa-pred arity)
    `(when (fixed-arity-predicate-p ,pred)
       (let ((,arity (arity ,pred)))
         (dotimes (,argnum-1 (1+ ,arity))
           (let ((,arg-isa-pred (arg-isa-pred ,argnum-1))
                 (,argnum-var ,argnum-1))
             (do-gaf-arg-index (,gaf-var ,pred :predicate ,arg-isa-pred
                                :index 1 :truth :true)
               ,@body)))))))

;; (defun kb-fol-predicate-arg-type-sentences (pred) ...) -- commented declareFunction, no body
;; (defun kb-fol-transitive-binary-predicate-sentences (pred) ...) -- commented declareFunction, no body
;; (defun kb-fol-symmetric-binary-predicate-sentences (pred) ...) -- commented declareFunction, no body
;; (defun kb-fol-asymmetric-binary-predicate-sentences (pred) ...) -- commented declareFunction, no body
;; (defun kb-fol-reflexive-binary-predicate-sentences (pred) ...) -- commented declareFunction, no body
;; (defun kb-fol-irreflexive-binary-predicate-sentences (pred) ...) -- commented declareFunction, no body
;; (defun kb-fol-tva-sentences (pred) ...) -- commented declareFunction, no body
;; (defun kb-fol-tva-sentences-int (pred) ...) -- commented declareFunction, no body
;; (defun kb-fol-tva-pred-neg-lit (pred constraint) ...) -- commented declareFunction, no body
;; (defun kb-fol-tva-pred-pos-lit (pred constraint) ...) -- commented declareFunction, no body
;; (defun replace-argnum-variable-formula (argnum formula replacement) ...) -- commented declareFunction, no body
;; (defun argnum-variable-formula (argnum) ...) -- commented declareFunction, no body
;; (defun kb-fol-nat-function-sentences (nart) ...) -- commented declareFunction, no body
;; (defun kb-fol-nat-argument-sentences (nart) ...) -- commented declareFunction, no body
;; (defun kb-fol-result-isa-sentences (func) ...) -- commented declareFunction, no body
;; (defun asent-sentence (asent mt type) ...) -- commented declareFunction, no body
;; (defun asent-fol-sentence (asent mt type) ...) -- commented declareFunction, no body
;; (defun genlmt-asent-fol-sentence (asent) ...) -- commented declareFunction, no body
;; (defun different-asent-fol-sentence (asent) ...) -- commented declareFunction, no body
;; (defun generic-asent-fol-sentence (asent mt type) ...) -- commented declareFunction, no body
;; (defun isa-asent-fol-sentence (asent mt type) ...) -- commented declareFunction, no body
;; (defun isa-asent-fol-sentence-as-isa (asent mt type) ...) -- commented declareFunction, no body
;; (defun isa-asent-fol-sentence-as-unary-predicate (asent type) ...) -- commented declareFunction, no body
;; (defun fol-transform-args (args) ...) -- commented declareFunction, no body
;; (defun fol-transform-arg (arg) ...) -- commented declareFunction, no body
;; (defun fol-transform-microtheory (mt) ...) -- commented declareFunction, no body
;; (defun asent-set-sentence (asent mt type) ...) -- commented declareFunction, no body
;; (defun genlmt-asent-set-sentence (asent) ...) -- commented declareFunction, no body
;; (defun generic-asent-set-sentence (asent mt type) ...) -- commented declareFunction, no body
;; (defun isa-asent-set-sentence (asent mt type) ...) -- commented declareFunction, no body
;; (defun different-asent-set-sentence (asent) ...) -- commented declareFunction, no body
;; (defun set-transform-args (args) ...) -- commented declareFunction, no body
;; (defun set-transform-function (func) ...) -- commented declareFunction, no body
;; (defun set-transform-arg (arg) ...) -- commented declareFunction, no body
;; (defun set-transform-microtheory (mt) ...) -- commented declareFunction, no body
;; (defun set-transform-predicate (pred type) ...) -- commented declareFunction, no body
;; (defun fol-transform-predicate (pred type) ...) -- commented declareFunction, no body
;; (defun fol-transform-col-as-predicate (col type) ...) -- commented declareFunction, no body
;; (defun fol-transform-function (func) ...) -- commented declareFunction, no body
;; (defun fol-term-p (object) ...) -- commented declareFunction, no body
;; (defun fol-represented-term-p (object) ...) -- commented declareFunction, no body
;; (defun fol-unrepresented-term-p (object) ...) -- commented declareFunction, no body
;; (defun make-fol-atomic-term (term) ...) -- commented declareFunction, no body
;; (defun fol-atomic-term-p (object) ...) -- commented declareFunction, no body
;; (defun make-fol-predicate (predicate arity) ...) -- commented declareFunction, no body
;; (defun fol-predicate-p (object) ...) -- commented declareFunction, no body
;; (defun make-fol-function (func arity) ...) -- commented declareFunction, no body
;; (defun fol-function-p (object) ...) -- commented declareFunction, no body
;; (defun fol-function-arity (fol-function) ...) -- commented declareFunction, no body
;; (defun make-fol-string (string) ...) -- commented declareFunction, no body
;; (defun fol-string-p (object) ...) -- commented declareFunction, no body
;; (defun fol-string-constant-p (object) ...) -- commented declareFunction, no body
;; (defun make-fol-number (number) ...) -- commented declareFunction, no body
;; (defun fol-number-p (object) ...) -- commented declareFunction, no body
;; (defun fol-number-constant-p (object) ...) -- commented declareFunction, no body
;; (defun fol-caf? (sentence) ...) -- commented declareFunction, no body
;; (defun fol-atomic-sentence? (sentence) ...) -- commented declareFunction, no body
;; (defun fol-closed? (sentence) ...) -- commented declareFunction, no body
;; (defun fol-sentences-data-mentioning-term (term data) ...) -- commented declareFunction, no body
;; (defun all-fol-predicates-and-arguments-mentioned-in-analysis (analysis) ...) -- commented declareFunction, no body
;; (defun all-fol-predicates-and-arguments-mentioned-in-analysis-data (data) ...) -- commented declareFunction, no body
;; (defun all-fol-predicates-and-arguments-mentioned-in-fol-datum (datum) ...) -- commented declareFunction, no body
;; (defun all-fol-predicates-and-arguments-mentioned-in-fol-sentences (sentences &optional initial) ...) -- commented declareFunction, no body
;; (defun all-fol-predicates-and-arguments-mentioned-in-focycl-sentence (sentence acc) ...) -- commented declareFunction, no body
;; (defun fol-header-to-stream (analysis format stream) ...) -- commented declareFunction, no body
;; (defun fol-datum-to-stream (datum format stream) ...) -- commented declareFunction, no body
;; (defun fol-sentences-to-cycl-stream (analysis stream) ...) -- commented declareFunction, no body
;; (defun fol-header-to-cycl-stream (analysis stream) ...) -- commented declareFunction, no body
;; (defun fol-datum-to-cycl-stream (datum stream) ...) -- commented declareFunction, no body
;; (defun fol-query-to-cycl-stream (sentence mt stream) ...) -- commented declareFunction, no body
;; (defun assertions-to-tptp-stream (analysis stream) ...) -- commented declareFunction, no body
;; (defun fol-sentences-to-tptp-stream (analysis stream) ...) -- commented declareFunction, no body
;; (defun fol-header-to-tptp-stream (analysis stream) ...) -- commented declareFunction, no body
;; (defun fol-datum-to-tptp-stream (datum stream) ...) -- commented declareFunction, no body
;; (defun output-tptp-term-comment (term stream) ...) -- commented declareFunction, no body
;; (defun fol-query-to-tptp-stream (sentence mt stream) ...) -- commented declareFunction, no body
;; (defun fol-generate-tptp-header (analysis) ...) -- commented declareFunction, no body
;; (defun fol-tptp-header-add-field (header field value) ...) -- commented declareFunction, no body
;; (defun fol-tptp-header-add-blankline (header) ...) -- commented declareFunction, no body
;; (defun clear-compute-tptp-query-index-number () ...) -- commented declareFunction, no body
;; (defun remove-compute-tptp-query-index-number (query) ...) -- commented declareFunction, no body
;; (defun compute-tptp-query-index-number-internal (query) ...) -- commented declareFunction, no body
;; (defun compute-tptp-query-index-number (query) ...) -- commented declareFunction, no body
;; (defun output-focycl-as-tptp (sentence stream include-comments?) ...) -- commented declareFunction, no body
;; (defun output-fol-query-as-tptp (sentence stream include-comments?) ...) -- commented declareFunction, no body
;; (defun output-tptp-axiom (sentence stream include-comments?) ...) -- commented declareFunction, no body
;; (defun tptp-axiom-id (assertion) ...) -- commented declareFunction, no body
;; (defun output-tptp-query (sentence stream include-comments?) ...) -- commented declareFunction, no body
;; (defun output-tptp-sentence-recursive (sentence stream) ...) -- commented declareFunction, no body
;; (defun output-tptp-arg (arg stream) ...) -- commented declareFunction, no body
;; (defun output-tptp-nat (nat stream) ...) -- commented declareFunction, no body
;; (defun output-tptp-predicate (predicate stream) ...) -- commented declareFunction, no body
;; (defun output-tptp-function (func stream) ...) -- commented declareFunction, no body
;; (defun output-tptp-zero-arity-function (func stream) ...) -- commented declareFunction, no body
;; (defun output-tptp-atomic-term (term stream) ...) -- commented declareFunction, no body
;; (defun output-tptp-string-constant (string-constant stream) ...) -- commented declareFunction, no body
;; (defun output-tptp-string (string stream) ...) -- commented declareFunction, no body
;; (defun output-tptp-number-constant (number-constant stream) ...) -- commented declareFunction, no body
;; (defun output-tptp-number (number stream) ...) -- commented declareFunction, no body
;; (defun output-tptp-variable (variable stream) ...) -- commented declareFunction, no body
;; (defun fol-tptp-el-var-name (el-var) ...) -- commented declareFunction, no body
;; (defun tptp-string-stringify (string) ...) -- commented declareFunction, no body
;; (defun clear-tptp-long-symbol-name-cache () ...) -- commented declareFunction, no body
;; (defun make-tptp-symbol-name (symbol) ...) -- commented declareFunction, no body
;; (defun tptp-downcase-stringify (object) ...) -- commented declareFunction, no body
;; (defun tptp-upcase-stringify (object) ...) -- commented declareFunction, no body
;; (defun tptp-number-stringify (number) ...) -- commented declareFunction, no body
;; (defun tptp-string-char-p (char) ...) -- commented declareFunction, no body
;; (defun tptp-non-numeric-atom-char-p (char) ...) -- commented declareFunction, no body
;; (defun tptp-numeric-atom-char-p (char) ...) -- commented declareFunction, no body
;; (defun focycl-to-cycl (focycl) ...) -- commented declareFunction, no body
;; (defun generate-symbol-index-file-from-kb (filename &optional properties) ...) -- commented declareFunction, no body
;; (defun fol-sentence-allowed-by-horn-handling (sentence handling) ...) -- commented declareFunction, no body
;; (defun generate-symbol-index-file-from-kb-int (analysis filename predicates functions terms pred-stream func-stream term-stream) ...) -- commented declareFunction, no body
;; (defun categorize-fol-terms (analysis) ...) -- commented declareFunction, no body
;; (defun categorize-fol-terms-int (datum) ...) -- commented declareFunction, no body
;; (defun print-symbol-index-term-string (term string stream) ...) -- commented declareFunction, no body
;; (defun fol-constant-string (constant) ...) -- commented declareFunction, no body
;; (defun clear-fol-nart-string () ...) -- commented declareFunction, no body
;; (defun remove-fol-nart-string (nart) ...) -- commented declareFunction, no body
;; (defun fol-nart-string-internal (nart) ...) -- commented declareFunction, no body
;; (defun fol-nart-string (nart) ...) -- commented declareFunction, no body
;; (defun write-deepak-opencyc-queries (directory filename) ...) -- commented declareFunction, no body
;; (defun deepak-kb-fol-sentences (&optional filename) ...) -- commented declareFunction, no body
;; (defun deepak-fol-query-to-tptp-stream (query-id mt stream &optional properties) ...) -- commented declareFunction, no body
;; (defun deepak-assertion-fol-sentences (assertion) ...) -- commented declareFunction, no body
;; (defun deepak-queries-timing-test () ...) -- commented declareFunction, no body
;; (defun deepak-queries-timing-test-2 (&optional max-time max-transformation-depth max-number) ...) -- commented declareFunction, no body
;; (defun deepak-queries-timing-test-int (query max-time max-transformation-depth max-number) ...) -- commented declareFunction, no body

;; Setup phase
(toplevel
  (note-globally-cached-function 'fol-sequence-variable-args-for-arity)
  (note-globally-cached-function 'compute-tptp-query-index-number)
  (declare-defglobal '*tptp-long-symbol-name-cache*)
  (note-globally-cached-function 'fol-nart-string))
