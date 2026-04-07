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


;; NOTE: This Java source (xml_utilities.java) is LarKC-stripped — all 68
;; active declareFunction entries have NO method bodies in the Java at all
;; (not even handleMissingMethodError). Function stubs below represent the
;; declared arities only. The 4 declareMacro entries are reconstructed from
;; Internal Constants evidence.


;; Variables (init phase)

(defparameter *xml-version* 1.0)
(defparameter *xml-indentation-level* 0)
(defparameter *xml-indentation-amount* 1)
(defparameter *cycml-indent-level* 0)

(deflexical *xml-cdata-prefix* "<![CDATA[")
(deflexical *xml-cdata-suffix* "]]>")

(deflexical *xml-base-char-code-ranges*
  (list '(65 90) '(97 122) '(192 214) '(216 246) '(248 255)
        '(256 305) '(308 318) '(321 328) '(330 382) '(384 451)
        '(461 496) '(500 501) '(506 535) '(592 680) '(699 705)
        '(902 902) '(904 906) '(908 908) '(910 929) '(931 974)
        '(976 982) '(986 986) '(988 988) '(990 990) '(992 992)
        '(994 1011) '(1025 1036) '(1038 1103) '(1105 1116)
        '(1118 1153) '(1168 1220) '(1223 1224) '(1227 1228)
        '(1232 1259) '(1262 1269) '(1272 1273) '(1329 1366)
        '(1369 1369) '(1377 1414) '(1488 1514) '(1520 1522)
        '(1569 1594) '(1601 1610) '(1649 1719) '(1722 1726)
        '(1728 1742) '(1744 1747) '(1749 1749) '(1765 1766)
        '(2309 2361) '(2365 2365) '(2392 2401) '(2437 2444)
        '(2447 2448) '(2451 2472) '(2474 2480) '(2482 2482)
        '(2486 2489) '(2524 2525) '(2527 2529) '(2544 2545)
        '(2565 2570) '(2575 2576) '(2579 2600) '(2602 2608)
        '(2610 2611) '(2613 2614) '(2616 2617) '(2649 2652)
        '(2654 2654) '(2674 2676) '(2693 2699) '(2701 2701)
        '(2703 2705) '(2707 2728) '(2730 2736) '(2738 2739)
        '(2741 2745) '(2749 2749) '(2784 2784) '(2821 2828)
        '(2831 2832) '(2835 2856) '(2858 2864) '(2866 2867)
        '(2870 2873) '(2877 2877) '(2908 2909) '(2911 2913)
        '(2949 2954) '(2958 2960) '(2962 2965) '(2969 2970)
        '(2972 2972) '(2974 2975) '(2979 2980) '(2984 2986)
        '(2990 2997) '(2999 3001) '(3077 3084) '(3086 3088)
        '(3090 3112) '(3114 3123) '(3125 3129) '(3168 3169)
        '(3205 3212) '(3214 3216) '(3218 3240) '(3242 3251)
        '(3253 3257) '(3294 3294) '(3296 3297) '(3333 3340)
        '(3342 3344) '(3346 3368) '(3370 3385) '(3424 3425)
        '(3585 3630) '(3632 3632) '(3634 3635) '(3648 3653)
        '(3713 3714) '(3716 3716) '(3719 3720) '(3722 3722)
        '(3725 3725) '(3732 3735) '(3737 3743) '(3745 3747)
        '(3749 3749) '(3751 3751) '(3754 3755) '(3757 3758)
        '(3760 3760) '(3762 3763) '(3773 3773) '(3776 3780)
        '(3904 3911) '(3913 3945) '(4256 4293) '(4304 4342)
        '(4352 4352) '(4354 4355) '(4357 4359) '(4361 4361)
        '(4363 4364) '(4366 4370) '(4412 4412) '(4414 4414)
        '(4416 4416) '(4428 4428) '(4430 4430) '(4432 4432)
        '(4436 4437) '(4441 4441) '(4447 4449) '(4451 4451)
        '(4453 4453) '(4455 4455) '(4457 4457) '(4461 4462)
        '(4466 4467) '(4469 4469) '(4510 4510) '(4520 4520)
        '(4523 4523) '(4526 4527) '(4535 4536) '(4538 4538)
        '(4540 4546) '(4587 4587) '(4592 4592) '(4601 4601)
        '(7680 7835) '(7840 7929) '(7936 7957) '(7960 7965)
        '(7968 8005) '(8008 8013) '(8016 8023) '(8025 8025)
        '(8027 8027) '(8029 8029) '(8031 8061) '(8064 8116)
        '(8118 8124) '(8126 8126) '(8130 8132) '(8134 8140)
        '(8144 8147) '(8150 8155) '(8160 8172) '(8178 8180)
        '(8182 8188) '(8486 8486) '(8490 8491) '(8494 8494)
        '(8576 8578) '(12353 12436) '(12449 12538) '(12549 12588)
        '(44032 55203)))

(deflexical *xml-ideographic-char-code-ranges*
  (list '(19968 40869) '(12295 12295) '(12321 12329)))

(defconstant *xml-special-chars*
  (list #\& #\" #\' #\> #\< #\Newline))

(defparameter *alists-sort-key* nil)


;; Functions (declare phase, all LarKC-stripped — no Java bodies)

;; (defun xml-version () ...) -- active declareFunction, no body
;; (defun xml-add-indentation (&optional stream) ...) -- active declareFunction, no body

;; Macro: WITH-XML-INDENTATION
;; Reconstructed from Internal Constants evidence:
;;   $sym1 CLET
;;   $list2 = ((*XML-INDENTATION-LEVEL* (+ *XML-INDENTATION-AMOUNT* *XML-INDENTATION-LEVEL*))
;;             (*CYCML-INDENT-LEVEL* *XML-INDENTATION-LEVEL*))
;; No $list for the outer arglist — the macro takes only &BODY BODY.
(defmacro with-xml-indentation (&body body)
  `(let ((*xml-indentation-level* (+ *xml-indentation-amount* *xml-indentation-level*))
         (*cycml-indent-level* *xml-indentation-level*))
     ,@body))

;; (defun xml-terpri () ...) -- active declareFunction, no body
;; (defun xml-write-string (string &optional start end) ...) -- active declareFunction, no body
;; (defun xml-write-char (char) ...) -- active declareFunction, no body
;; (defun xml-write-string-indented (string &optional start end) ...) -- active declareFunction, no body
;; (defun xml-header (&optional version encoding standalone?) ...) -- active declareFunction, no body
;; (defun xml-cdata-prefix () ...) -- active declareFunction, no body
;; (defun xml-cdata-suffix () ...) -- active declareFunction, no body
;; (defun xml-cdata (string) ...) -- active declareFunction, no body
;; (defun xml-markup (string) ...) -- active declareFunction, no body
;; (defun xml-comment (string) ...) -- active declareFunction, no body

;; Macro: XML-TAG
;; Reconstructed from Internal Constants evidence:
;;   $list21 arglist: ((NAME &OPTIONAL ATTRIBUTES ATOMIC? NO-NESTED-ELEMENTS?) &BODY BODY)
;;   $sym22 PROGN, $sym23 WITH-XML-INDENTATION, $sym24 XML-START-TAG-INTERNAL,
;;   $sym25 PUNLESS, $list26 ((XML-TERPRI)), $sym27 XML-END-TAG-INTERNAL
(defmacro xml-tag ((name &optional attributes atomic? no-nested-elements?) &body body)
  `(progn
     (xml-start-tag-internal ,name ,attributes ,atomic?)
     (with-xml-indentation
       ,@body)
     (unless ,no-nested-elements?
       (xml-terpri))
     (xml-end-tag-internal ,name)))

;; (defun xml-start-tag-internal (name attributes atomic?) ...) -- active declareFunction, no body
;; (defun xml-end-tag-internal (name) ...) -- active declareFunction, no body
;; (defun xml-print (object &optional stream) ...) -- active declareFunction, no body
;; (defun xml-prin1 (object &optional stream) ...) -- active declareFunction, no body
;; (defun xml-print-line (object &optional stream) ...) -- active declareFunction, no body
;; (defun xml-prin1-line (object &optional stream) ...) -- active declareFunction, no body
;; (defun xml-write (object &optional stream) ...) -- active declareFunction, no body
;; (defun xml-write-line (object &optional stream) ...) -- active declareFunction, no body
;; (defun valid-xml-name-p (string) ...) -- active declareFunction, no body
;; (defun remove-invalid-xml-name-chars (string) ...) -- active declareFunction, no body
;; (defun valid-ascii-xml-name-p (string) ...) -- active declareFunction, no body
;; (defun valid-xml-name-initial-char-p (char) ...) -- active declareFunction, no body
;; (defun valid-xml-name-initial-char-code-p (code) ...) -- active declareFunction, no body
;; (defun valid-non-ascii-xml-name-p (string) ...) -- active declareFunction, no body
;; (defun valid-xml-name-char-p (char) ...) -- active declareFunction, no body
;; (defun remove-invalid-xml-name-chars-from-ascii-string (string) ...) -- active declareFunction, no body
;; (defun remove-invalid-xml-name-chars-from-non-ascii-string (string) ...) -- active declareFunction, no body
;; (defun valid-xml-name-char-code-p (code) ...) -- active declareFunction, no body
;; (defun digit-char-code-p (code) ...) -- active declareFunction, no body
;; (defun xml-letter-char-p (char) ...) -- active declareFunction, no body
;; (defun xml-letter-char-code-p (code) ...) -- active declareFunction, no body
;; (defun xml-base-char-p (char) ...) -- active declareFunction, no body
;; (defun xml-base-char-code-p (code) ...) -- active declareFunction, no body
;; (defun xml-ideographic-char-p (char) ...) -- active declareFunction, no body
;; (defun xml-ideographic-char-code-p (code) ...) -- active declareFunction, no body
;; (defun valid-xml-char-p (char) ...) -- active declareFunction, no body
;; (defun valid-xml-char-code-p (code) ...) -- active declareFunction, no body
;; (defun char-in-ranges-p (char ranges) ...) -- active declareFunction, no body
;; (defun char-code-in-ranges-p (code ranges) ...) -- active declareFunction, no body
;; (defun xml-special-char? (char) ...) -- active declareFunction, no body
;; (defun xml-char-escaped-version (char) ...) -- active declareFunction, no body
;; (defun xml-write-w/escaped-special-chars (string) ...) -- active declareFunction, no body
;; (defun possible-xml-entity-reference-p (string &optional start end) ...) -- active declareFunction, no body
;; (defun possible-xml-entity-name-p (string) ...) -- active declareFunction, no body
;; (defun possible-xml-numeric-character-reference-p (string) ...) -- active declareFunction, no body
;; (defun valid-xml-entity-name-first-char-p (char) ...) -- active declareFunction, no body
;; (defun valid-xml-entity-name-char-p (char) ...) -- active declareFunction, no body

;; Macro: WITH-XML-OUTPUT-TO-STREAM
;; Reconstructed from Internal Constants evidence:
;;   $list53 arglist: (STREAM &BODY BODY)
;;   $sym54 *XML-STREAM*
(defmacro with-xml-output-to-stream (stream &body body)
  `(let ((*xml-stream* ,stream))
     ,@body))

;; Macro: WITH-XML-OUTPUT-TO-STRING
;; Reconstructed from Internal Constants evidence:
;;   $list55 arglist: (STRING-VAR &BODY BODY)
;;   $sym57 STREAM = makeUninternedSymbol("STREAM") — gensym for temp stream
;;   $sym58 CWITH-OUTPUT-TO-STRING, $sym59 WITH-XML-OUTPUT-TO-STREAM
(defmacro with-xml-output-to-string (string-var &body body)
  (with-temp-vars (stream)
    `(let ((,string-var
             (with-output-to-string (,stream)
               (with-xml-output-to-stream ,stream
                 ,@body))))
       ,string-var)))

;; (defun generate-valid-xml-header (dtd-info) ...) -- active declareFunction, no body
;; (defun generate-xml-header-entry-for-dtd (root-element system-dtd-uri public-dtd-uri) ...) -- active declareFunction, no body
;; (defun resolve-xml-namespaces (token namespace-stack) ...) -- active declareFunction, no body
;; (defun maybe-resolve-xml-namespace (name namespace-stack type) ...) -- active declareFunction, no body
;; (defun resolve-xml-namespace (name namespace-stack type) ...) -- active declareFunction, no body
;; (defun xml-sexpr-output-as-xml (sexpr) ...) -- active declareFunction, no body
;; (defun xml-sexpr-output-daughters (sexpr &optional indent) ...) -- active declareFunction, no body
;; (defun xml-tag-attributes-from-sexpr (sexpr) ...) -- active declareFunction, no body
;; (defun alists-sort-key (binding) ...) -- active declareFunction, no body
;; (defun attribute-vars (xml-spec) ...) -- active declareFunction, no body
;; (defun sort-query-results-on-el-var (results var) ...) -- active declareFunction, no body
;; (defun write-xml-from-grouped-bindings (grouped-bindings el-vars xml-spec root-element-name stream) ...) -- active declareFunction, no body
;; (defun query-bindings-to-xml (bindings el-vars xml-spec root-element-name stream) ...) -- active declareFunction, no body
;; (defun get-default-xml-spec-for-el-vars (el-vars) ...) -- active declareFunction, no body
;; (defun query-bindings-to-xml-stream (bindings el-vars xml-spec root-element-name &optional stream) ...) -- active declareFunction, no body
;; (defun query-results-to-xml-stream (results &optional el-vars xml-spec root-element-name stream) ...) -- active declareFunction, no body, Cyc API
;; (defun query-results-to-xml-file (results file &optional el-vars xml-spec root-element-name) ...) -- active declareFunction, no body, Cyc API
;; (defun query-results-to-xml-string (results &optional el-vars xml-spec root-element-name) ...) -- active declareFunction, no body, Cyc API
;; (defun boolean-to-true/false-string (bool) ...) -- active declareFunction, no body


;; Setup phase

(define-obsolete-register 'generate-valid-xml-header '(xml-header))
(register-external-symbol 'query-results-to-xml-stream)
(register-external-symbol 'query-results-to-xml-file)
(register-external-symbol 'query-results-to-xml-string)
