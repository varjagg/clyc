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

;; English-language morphology: vowel/consonant classification, syllable
;; estimation, inflection/derivation suffixing, stemming, and part-of-speech
;; probes. All function bodies are missing-larkc.

;;; Functions (declare section ordering, all commented-out declareFunctions)

;; (defun get-vowel-positions (string) ...) -- commented declareFunction, no body
;; (defun estimated-syllable-count (string) ...) -- commented declareFunction, no body
;; (defun monosyllabic? (string) ...) -- commented declareFunction, no body
;; (defun polysyllabic? (string &optional syllable-count) ...) -- commented declareFunction, no body
;; (defun vowel-char? (char &optional include-y?) ...) -- commented declareFunction, no body
;; (defun consonant-char? (char) ...) -- commented declareFunction, no body
;; (defun get-consonant-positions (string) ...) -- commented declareFunction, no body
;; (defun ends-with-vowel? (string) ...) -- commented declareFunction, no body
;; (defun starts-with-vowel? (string) ...) -- commented declareFunction, no body
;; (defun ends-with-consonant? (string) ...) -- commented declareFunction, no body
;; (defun starts-with-consonant? (string) ...) -- commented declareFunction, no body
;; (defun single-c-coda? (string) ...) -- commented declareFunction, no body
;; (defun ends-with-doubler? (string) ...) -- commented declareFunction, no body
;; (defun starts-with-unstressed-pfx? (string) ...) -- commented declareFunction, no body
;; (defun ends-in-cvc? (string) ...) -- commented declareFunction, no body
;; (defun ends-in-quvc? (string) ...) -- commented declareFunction, no body
;; (defun make-geminate (string char) ...) -- commented declareFunction, no body
;; (defun geminate-last (string) ...) -- commented declareFunction, no body
;; (defun correct-capitalization (new-string old-string) ...) -- commented declareFunction, no body
;; (defun regular-string-function (form) ...) -- commented declareFunction, no body
;; (defun suffix-rules-for-pred (pred) ...) -- commented declareFunction, no body
;; (defun generate-regular-string-from-form (string pred form &optional mt) ...) -- commented declareFunction, no body
;; (defun generate-regular-strings-from-form (string pred form &optional suffix-rules mt fast?) ...) -- commented declareFunction, no body
;; (defun generate-regular-strings-from-form-int (string pred form suffix-rules mt fast?) ...) -- commented declareFunction, no body
;; (defun add-english-suffix (string suffix) ...) -- commented declareFunction, no body
;; (defun aes-do-orthographic-changes (string suffix) ...) -- commented declareFunction, no body
;; (defun aes-do-orthographic-change-fns () ...) -- commented declareFunction, no body
;; (defun aes-do-orthographic-change (string suffix change-fn type) ...) -- commented declareFunction, no body
;; (defun ends-with-sibilant? (string) ...) -- commented declareFunction, no body
;; (defun aes-add-e-before-s (string suffix) ...) -- commented declareFunction, no body; handleMissingMethodError #12884
;; (defun aes-change-y-to-i (string suffix) ...) -- commented declareFunction, no body; handleMissingMethodError #12890
;; (defun aes-ble-to-bil-before-ity (string suffix) ...) -- commented declareFunction, no body; handleMissingMethodError #12885
;; (defun aes-change-aic-to-ac (string suffix) ...) -- commented declareFunction, no body; handleMissingMethodError #12886
;; (defun aes-strip-final-e (string suffix) ...) -- commented declareFunction, no body; handleMissingMethodError #12895
;; (defun aes-strip-final-vowels-before-ic (string suffix) ...) -- commented declareFunction, no body; handleMissingMethodError #12896
;; (defun aes-change-ie-to-y (string suffix) ...) -- commented declareFunction, no body; handleMissingMethodError #12888
;; (defun aes-change-ism-to-ist (string suffix) ...) -- commented declareFunction, no body; handleMissingMethodError #12889
;; (defun aes-change-ceive-to-cept (string suffix) ...) -- commented declareFunction, no body; handleMissingMethodError #12887
;; (defun aes-remove-able-le-before-ly (string suffix) ...) -- commented declareFunction, no body; handleMissingMethodError #12894
;; (defun aes-geminate-last (string suffix) ...) -- commented declareFunction, no body; handleMissingMethodError #12893
;; (defun aes-able-to-ate (string suffix) ...) -- commented declareFunction, no body; handleMissingMethodError #12883
;; (defun try-regular-adj-morphology? (string) ...) -- commented declareFunction, no body
;; (defun most-form (string) ...) -- commented declareFunction, no body
;; (defun more-form (string) ...) -- commented declareFunction, no body
;; (defun most-form-p (string) ...) -- commented declareFunction, no body
;; (defun more-form-p (string) ...) -- commented declareFunction, no body
;; (defun more-or-most-form-p (string prefix) ...) -- commented declareFunction, no body
;; (defun comparative-reg (string) ...) -- commented declareFunction, no body
;; (defun comparative-adverb-reg (string) ...) -- commented declareFunction, no body
;; (defun superlative-reg (string) ...) -- commented declareFunction, no body
;; (defun superlative-adverb-reg (string) ...) -- commented declareFunction, no body
;; (defun past-tense-reg (string) ...) -- commented declareFunction, no body
;; (defun gerund-reg (string) ...) -- commented declareFunction, no body
;; (defun third-sg-reg (string) ...) -- commented declareFunction, no body
;; (defun plural-reg (string) ...) -- commented declareFunction, no body
;; (defun pn-plural-reg (string) ...) -- commented declareFunction, no body
;; (defun infinitive-to-third-sing (string) ...) -- commented declareFunction, no body
;; (defun infinitive-to-pres-participle (string) ...) -- commented declareFunction, no body
;; (defun possessivize-string (string &optional capitalize?) ...) -- commented declareFunction, no body
;; (defun english-lexical-possessive-version-of-string (string) ...) -- commented declareFunction, no body
;; (defun english-possessive-suffix-for-string (string &optional capitalize?) ...) -- commented declareFunction, no body
;; (defun locativize-string (string denot) ...) -- commented declareFunction, no body
;; (defun not-locativizable-english-string? (string) ...) -- commented declareFunction, no body
;; (defun english-locative-preposition-for-denot (denot) ...) -- commented declareFunction, no body
;; (defun pluralize-string (string &optional mt) ...) -- commented declareFunction, no body
;; (defun singularize-string (string &optional mt) ...) -- commented declareFunction, no body
;; (defun has-word-for-string-and-pos (string pos) ...) -- commented declareFunction, no body
;; (defun has-word-for-string-and-pos-list (string pos-list) ...) -- commented declareFunction, no body
;; (defun is-word (string) ...) -- commented declareFunction, no body
;; (defun is-noun (string) ...) -- commented declareFunction, no body
;; (defun is-verb (string) ...) -- commented declareFunction, no body
;; (defun is-noun-or-verb (string) ...) -- commented declareFunction, no body
;; (defun clear-find-stem-memoized () ...) -- commented declareFunction, no body
;; (defun remove-find-stem-memoized (string &optional pos) ...) -- commented declareFunction, no body
;; (defun find-stem-memoized-internal (string pos) ...) -- commented declareFunction, no body
;; (defun find-stem-memoized (string &optional pos) ...) -- commented declareFunction, no body
;; (defun find-stem (string &optional pos) ...) -- commented declareFunction, no body
;; (defun inflected-verb-to-infinitive (string) ...) -- commented declareFunction, no body
;; (defun agentive-to-infinitive (string) ...) -- commented declareFunction, no body
;; (defun third-sg-verb-to-infinitive (string) ...) -- commented declareFunction, no body
;; (defun plural-noun-to-sg (string &optional mt) ...) -- commented declareFunction, no body
;; (defun singular-reg (string) ...) -- commented declareFunction, no body
;; (defun plural-noun? (string) ...) -- commented declareFunction, no body
;; (defun infinitive-verb? (string) ...) -- commented declareFunction, no body
;; (defun progressive-string? (string) ...) -- commented declareFunction, no body
;; (defun perfect-string? (string) ...) -- commented declareFunction, no body
;; (defun 3sg-string? (string) ...) -- commented declareFunction, no body
;; (defun numberspp (string) ...) -- commented declareFunction, no body
;; (defun comparative-degree? (string) ...) -- commented declareFunction, no body
;; (defun superlative-degree? (string) ...) -- commented declareFunction, no body
;; (defun pos-of-unknown-word (string) ...) -- commented declareFunction, no body
;; (defun proper-nounp (string) ...) -- commented declareFunction, no body
;; (defun verbp (string) ...) -- commented declareFunction, no body
;; (defun nounp (string) ...) -- commented declareFunction, no body
;; (defun adjectivep (string) ...) -- commented declareFunction, no body
;; (defun adverbp (string) ...) -- commented declareFunction, no body
;; (defun pos-keyword-p (object) ...) -- commented declareFunction, no body
;; (defun root-predicate (pos) ...) -- commented declareFunction, no body
;; (defun get-root-of-head (string &optional pos) ...) -- commented declareFunction, no body
;; (defun get-root (string &optional pos) ...) -- commented declareFunction, no body
;; (defun expand-contracted-root (string) ...) -- commented declareFunction, no body


;;; Variables

(defconstant *vowels* "aeiou")

(defconstant *bigraph-vowels*
  '("ai" "au" "ay" "ea" "ee" "ei" "eu" "ie" "io" "oa" "oi" "oo" "ou" "ow" "oy" "ui")
  "[Cyc] List of vowel character pairs that often occur within a single syllable")

(defconstant *sibilant-endings* '("ss" "x" "sh" "ch" "z" "s"))

(defconstant *consonants* "bcdfghjklmnprstvxz")

(defconstant *doublers* "bdfgklmnprtvz")

(defconstant *unstressed-latin-pfxs* '("re" "de" "dis" "mis" "un" "in" "ex"))

(defconstant *special-ate-cases*
  '("evaporate" "appreciate" "associate" "accommodate" "affiliate" "applicate"
    "navigate" "calculate" "abdicate" "estimate" "emulate" "educate"))

(defconstant *liquids* '("l" "r"))

(defconstant *vowels*-plus-y* (concatenate 'string *vowels* "y"))

(deflexical *aes-do-orthographic-change-fns*
  '((aes-change-y-to-i . :both)
    (aes-able-to-ate . :base)
    (aes-geminate-last . :base)
    (aes-ble-to-bil-before-ity . :base)
    (aes-change-ceive-to-cept . :base)
    (aes-change-aic-to-ac . :base)
    (aes-strip-final-e . :base)
    (aes-strip-final-vowels-before-ic . :base)
    (aes-change-ie-to-y . :base)
    (aes-change-ism-to-ist . :base)
    (aes-remove-able-le-before-ly . :base)
    (aes-add-e-before-s . :suffix)))

(deflexical *comparative-syllable-cutoff* 2
  "[Cyc] Maximum number of syllables for comparative and superlative adjectives that use -er")

(defconstant *more-prefix* "more ")

(defconstant *most-prefix* "most ")

(defconstant *english-possessive-pronouns*
  '(("I" . "my")
    ("me" . "my")
    ("you" . "your")
    ("he" . "his")
    ("him" . "his")
    ("him or her" . "his or her")
    ("he or she" . "his or her")
    ("she" . "her")
    ("her" . "her")
    ("it" . "its")
    ("we" . "our")
    ("us" . "our")
    ("they" . "their")
    ("them" . "their")
    ("there" . "that place's")
    ("here" . "this place's")))

(deflexical *find-stem-memoized-caching-state* nil)

(defparameter *preserve-case-in-singular-reg?* nil
  "[Cyc] @hack, but I have no idea what the consequences of a larger fix might be... or why downcasing occurs at all. --TW")

(defparameter *pos-keywords*
  '(:noun :proper-noun :verb :adjective :adverb :preposition)
  "[Cyc] part-of-speech keywords currently supported")


;;; Setup phase

(toplevel
  (note-globally-cached-function 'find-stem-memoized)
  (register-external-symbol 'plural-noun-to-sg))
