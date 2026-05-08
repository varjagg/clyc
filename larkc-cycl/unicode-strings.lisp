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

;; Definitions

(defconstant max-unicode-value 1114111)

;; UNICODE-CHAR defstruct
;; print-object is missing-larkc 30929 — CL's default print-object handles this.
(defstruct unicode-char
  uchar)

(defconstant *dtp-unicode-char* 'unicode-char)

;; unicode-char-p -- active declareFunction, provided by defstruct
;; unicode-char-uchar -- active declareFunction, provided by defstruct
;; _csetf-unicode-char-uchar -- active declareFunction, no body; defstruct provides (setf unicode-char-uchar)
;; make-unicode-char -- active declareFunction, no body; provided by defstruct

;; (defun unicode-char-create (code) ...) -- active declareFunction, no body

;; (defun print-unicode-char (object stream depth) ...) -- active declareFunction, no body

;; (defun unicode-char-get-char (unicode-char) ...) -- active declareFunction, no body

;; (defun unicode-char-set-char (unicode-char value) ...) -- active declareFunction, no body

;; UNICODE-STRING defstruct
;; print-object is missing-larkc 30930 — CL's default print-object handles this.
(defstruct unicode-string
  vect)

(defconstant *dtp-unicode-string* 'unicode-string)

;; unicode-string-p -- active declareFunction, provided by defstruct
;; unicode-string-vect -- active declareFunction, provided by defstruct
;; _csetf-unicode-string-vect -- active declareFunction, no body; defstruct provides (setf unicode-string-vect)
;; make-unicode-string -- active declareFunction, no body; provided by defstruct

;; (defun unicode-string-create (vector) ...) -- active declareFunction, no body

;; (defun print-unicode-string (object stream depth) ...) -- active declareFunction, no body

;; (defun unicode-string-get-vector (unicode-string) ...) -- active declareFunction, no body

;; (defun unicode-string-set-vector (unicode-string vector) ...) -- active declareFunction, no body

;; (defun unicode-vector-string-p (object) ...) -- active declareFunction, no body

;; (defun utf8-vector-string-p (object) ...) -- active declareFunction, no body

(defun ascii-string-p (object)
  "[Cyc] Return T iff OBJECT is a string of ASCII characters."
  (if (not (stringp object))
      nil
      (dotimes (i (length object) t)
        (let ((v-char (char object i)))
          (when (null (ascii-char-p-int v-char))
            (return nil))))))

;; (defun non-ascii-string-p (object) ...) -- active declareFunction, no body

;; (defun ascii-char-p (object) ...) -- active declareFunction, no body

;; (defun non-ascii-char-p (object) ...) -- active declareFunction, no body

(defun ascii-char-p-int (v-char)
  "[Cyc] Return T iff V-CHAR's char-code is <= 127."
  (if (<= (char-code v-char) 127) t nil))

;; (defun display-vector-is-ascii-p (vector) ...) -- active declareFunction, no body

;; (defun display-vector-string-p (object) ...) -- active declareFunction, no body

;; (defun display-to-unicode-vector (display) ...) -- active declareFunction, no body

(deflexical *default-non-ascii-placeholder-char* #\~)

(defparameter *default-unicode-to-ascii-code-map*
  '((192 . 65) (193 . 65) (194 . 65) (195 . 65) (196 . 65) (197 . 65)
    (200 . 69) (201 . 69) (202 . 69) (203 . 69)
    (204 . 73) (205 . 73) (206 . 73) (207 . 73)
    (209 . 78)
    (210 . 79) (211 . 79) (212 . 79) (213 . 79) (214 . 79) (216 . 79)
    (217 . 85) (218 . 85) (219 . 85) (220 . 85)
    (221 . 89)
    (224 . 97) (225 . 97) (226 . 97) (227 . 97) (228 . 97) (229 . 97)
    (231 . 99)
    (232 . 101) (233 . 101) (234 . 101) (235 . 101)
    (236 . 105) (237 . 105) (238 . 105) (239 . 105)
    (240 . 100)
    (241 . 110)
    (242 . 111) (243 . 111) (244 . 111) (245 . 111) (246 . 111) (248 . 111)
    (249 . 117) (250 . 117) (251 . 117) (252 . 117)
    (253 . 121) (255 . 121)))

(defun display-to-subl-string (display &optional (placeholder-char *default-non-ascii-placeholder-char*) (subst-alist *default-unicode-to-ascii-code-map*))
  "[Cyc] Convert DISPLAY to a valid SubL string, replacing non-ASCII characters with PLACEHOLDER-CHAR if
not mentioned in SUBST-ALIST."
  ;; Body uses missing-larkc call internally for display-to-unicode-vector (30908)
  (let* ((unicode-vector (missing-larkc 30908))
         (length (length unicode-vector))
         (string (make-string length :initial-element placeholder-char)))
    (dotimes (v-iteration length)
      (let* ((index v-iteration)
             (code (aref unicode-vector index)))
        (cond ((and (>= code 128)
                    (alist-lookup subst-alist code #'eql nil))
               (setf (char string index)
                     (code-char (alist-lookup subst-alist code #'eql nil))))
              ((< code 128)
               (setf (char string index) (code-char code))))))
    string))

;; (defun unicode-vector-to-display (unicode-vector) ...) -- active declareFunction, no body

;; (defun element-vector (code vector) ...) -- active declareFunction, no body

;; (defun unicode-vector-to-utf8-vector (unicode-vector &optional start end) ...) -- active declareFunction, no body

;; (defun utf8-vector-to-unicode-vector (utf8-vector) ...) -- active declareFunction, no body

;; (defun unicode-char-code-fn (unicode-char) ...) -- active declareFunction, no body

;; (defun unicode-code-char (code) ...) -- active declareFunction, no body

;; (defun unicode-character-p (object) ...) -- active declareFunction, no body

;; (defun number-utf8-bytes (code) ...) -- active declareFunction, no body

;; (defun to-utf8-vector (code) ...) -- active declareFunction, no body

;; (defun print-utf-hex-list (vector) ...) -- active declareFunction, no body

;; (defun to-utc8-vector-internal (code nbytes result) ...) -- active declareFunction, no body

;; (defun length-utf8-vector-codepoint (vector offset) ...) -- active declareFunction, no body

;; (defun length-utf8-from-first-byte (byte) ...) -- active declareFunction, no body

;; (defun utf8-vector-is-ascii-string-p (vector &optional start end) ...) -- active declareFunction, no body

;; (defun utf8-char-is-ascii-p (vector offset) ...) -- active declareFunction, no body

;; (defun unicode-vector-is-ascii-string-p (vector &optional start end) ...) -- active declareFunction, no body

;; (defun unicode-char-is-ascii-char-p (code) ...) -- active declareFunction, no body

;; (defun utf8-char-p-fn (vector offset) ...) -- active declareFunction, no body

;; (defun get-unicode-char-at-or-after-offset (vector offset) ...) -- active declareFunction, no body

;; (defun get-unicode-char-at-or-before-offset (vector offset) ...) -- active declareFunction, no body

;; (defun get-unicode-char-at-offset (vector offset) ...) -- active declareFunction, no body

;; (defun string-from-char-list (char-list &optional size) ...) -- active declareFunction, no body

;; (defun unicode-to-html-escaped (code) ...) -- active declareFunction, no body

;; (defun unicode-string-to-utf8 (unicode-string) ...) -- active declareFunction, no body

;; (defun unicode-string-to-subl-string (unicode-string) ...) -- active declareFunction, no body

;; (defun unicode-display-to-utf8 (display) ...) -- active declareFunction, no body

;; (defun unicode-display-to-html (display) ...) -- active declareFunction, no body

;; (defun html-escaped-to-utf8-vector (html-string) ...) -- active declareFunction, no body

;; (defun utf8-string-to-unicode-vector (utf8-string) ...) -- active declareFunction, no body

;; (defun html-escaped-to-unicode-vector (html-string) ...) -- active declareFunction, no body

;; (defun utf8-vector-to-utf8-string (utf8-vector) ...) -- active declareFunction, no body

;; (defun utf8-string-to-utf8-vector (utf8-string) ...) -- active declareFunction, no body

(defun utf8-string-to-subl-string (utf8-string)
  "[Cyc] Convert UTF8-STRING to a SubL string."
  (display-to-subl-string (missing-larkc 30945)))

;; (defun utf8-string-to-display (utf8-string) ...) -- active declareFunction, no body

;; (defun html-escaped-to-utf8-string (html-string) ...) -- active declareFunction, no body

;; (defun display-to-utf8-string (display) ...) -- active declareFunction, no body

;; (defun html-escaped-to-display (html-string) ...) -- active declareFunction, no body

;; (defun map-character-entity-to-decimal-value (entity) ...) -- active declareFunction, no body

;; (defun map-decimal-value-to-character-entity (value) ...) -- active declareFunction, no body

;; (defun unicode-string-concatenate (string1 string2) ...) -- active declareFunction, no body

;; CFASL support

(defconstant *cfasl-opcode-unicode-char* 52)

(defun cfasl-output-object-unicode-char-method (object stream)
  "[Cyc] CFASL output method for UNICODE-CHAR objects."
  (missing-larkc 30904))

;; (defun cfasl-output-unicode-char (unicode-char stream) ...) -- active declareFunction, no body

;; (defun cfasl-input-unicode-char (stream) ...) -- active declareFunction, no body

(defconstant *cfasl-opcode-unicode-string* 53)

(defun cfasl-output-object-unicode-string-method (object stream)
  "[Cyc] CFASL output method for UNICODE-STRING objects."
  (missing-larkc 30905))

;; (defun cfasl-output-unicode-string (unicode-string stream) ...) -- active declareFunction, no body

;; (defun cfasl-input-unicode-string (stream) ...) -- active declareFunction, no body

(deflexical *html-40-character-entity-table*
  '(("AElig" . 198) ("Aacute" . 193) ("Acirc" . 194) ("Agrave" . 192)
    ("Alpha" . 913) ("Aring" . 197) ("Atilde" . 195) ("Auml" . 196)
    ("Beta" . 914) ("Ccedil" . 199) ("Chi" . 935) ("Dagger" . 8225)
    ("Delta" . 916) ("ETH" . 208) ("Eacute" . 201) ("Ecirc" . 202)
    ("Egrave" . 200) ("Epsilon" . 917) ("Eta" . 919) ("Euml" . 203)
    ("Gamma" . 915) ("Iacute" . 205) ("Icirc" . 206) ("Igrave" . 204)
    ("Iota" . 921) ("Iuml" . 207) ("Kappa" . 922) ("Lambda" . 923)
    ("Mu" . 924) ("Ntilde" . 209) ("Nu" . 925) ("OElig" . 338)
    ("Oacute" . 211) ("Ocirc" . 212) ("Ograve" . 210) ("Omega" . 937)
    ("Omicron" . 927) ("Oslash" . 216) ("Otilde" . 213) ("Ouml" . 214)
    ("Phi" . 934) ("Pi" . 928) ("Prime" . 8243) ("Psi" . 936)
    ("Rho" . 929) ("Scaron" . 352) ("Sigma" . 931) ("THORN" . 222)
    ("Tau" . 932) ("Theta" . 920) ("Uacute" . 218) ("Ucirc" . 219)
    ("Ugrave" . 217) ("Upsilon" . 933) ("Uuml" . 220) ("Xi" . 926)
    ("Yacute" . 221) ("Yuml" . 376) ("Zeta" . 918)
    ("aacute" . 225) ("acirc" . 226) ("acute" . 180) ("aelig" . 230)
    ("agrave" . 224) ("alefsym" . 8501) ("alpha" . 945) ("amp" . 38)
    ("and" . 8743) ("ang" . 8736) ("aring" . 229) ("asymp" . 8776)
    ("atilde" . 227) ("auml" . 228) ("bdquo" . 8222) ("beta" . 946)
    ("brvbar" . 166) ("bull" . 8226) ("cap" . 8745) ("ccedil" . 231)
    ("cedil" . 184) ("cent" . 162) ("chi" . 967) ("circ" . 710)
    ("clubs" . 9827) ("cong" . 8773) ("copy" . 169) ("crarr" . 8629)
    ("cup" . 8746) ("curren" . 164) ("dArr" . 8659) ("dagger" . 8224)
    ("darr" . 8595) ("deg" . 176) ("delta" . 948) ("diams" . 9830)
    ("divide" . 247) ("eacute" . 233) ("ecirc" . 234) ("egrave" . 232)
    ("empty" . 8709) ("emsp" . 8195) ("ensp" . 8194) ("epsilon" . 949)
    ("equiv" . 8801) ("eta" . 951) ("eth" . 240) ("euml" . 235)
    ("euro" . 8364) ("exist" . 8707) ("fnof" . 402) ("forall" . 8704)
    ("frac12" . 189) ("frac14" . 188) ("frac34" . 190) ("frasl" . 8260)
    ("gamma" . 947) ("ge" . 8805) ("gt" . 62) ("hArr" . 8660)
    ("harr" . 8596) ("hearts" . 9829) ("hellip" . 8230) ("iacute" . 237)
    ("icirc" . 238) ("iexcl" . 161) ("igrave" . 236) ("image" . 8465)
    ("infin" . 8734) ("int" . 8747) ("iota" . 953) ("iquest" . 191)
    ("isin" . 8712) ("iuml" . 239) ("kappa" . 954) ("lArr" . 8656)
    ("lambda" . 955) ("lang" . 9001) ("laquo" . 171) ("larr" . 8592)
    ("lceil" . 8968) ("ldquo" . 8220) ("le" . 8804) ("lfloor" . 8970)
    ("lowast" . 8727) ("loz" . 9674) ("lrm" . 8206) ("lsaquo" . 8249)
    ("lsquo" . 8216) ("lt" . 60) ("macr" . 175) ("mdash" . 8212)
    ("micro" . 181) ("middot" . 183) ("minus" . 8722) ("mu" . 956)
    ("nabla" . 8711) ("nbsp" . 160) ("ndash" . 8211) ("ne" . 8800)
    ("ni" . 8715) ("not" . 172) ("notin" . 8713) ("nsub" . 8836)
    ("ntilde" . 241) ("nu" . 957) ("oacute" . 243) ("ocirc" . 244)
    ("oelig" . 339) ("ograve" . 242) ("oline" . 8254) ("omega" . 969)
    ("omicron" . 959) ("oplus" . 8853) ("or" . 8744) ("ordf" . 170)
    ("ordm" . 186) ("oslash" . 248) ("otilde" . 245) ("otimes" . 8855)
    ("ouml" . 246) ("para" . 182) ("part" . 8706) ("permil" . 8240)
    ("perp" . 8869) ("phi" . 966) ("pi" . 960) ("piv" . 982)
    ("plusmn" . 177) ("pound" . 163) ("prime" . 8242) ("prod" . 8719)
    ("prop" . 8733) ("psi" . 968) ("quot" . 34) ("rArr" . 8658)
    ("radic" . 8730) ("rang" . 9002) ("raquo" . 187) ("rarr" . 8594)
    ("rceil" . 8969) ("rdquo" . 8221) ("real" . 8476) ("reg" . 174)
    ("rfloor" . 8971) ("rho" . 961) ("rlm" . 8207) ("rsaquo" . 8250)
    ("rsquo" . 8217) ("sbquo" . 8218) ("scaron" . 353) ("sdot" . 8901)
    ("sect" . 167) ("shy" . 173) ("sigma" . 963) ("sigmaf" . 962)
    ("sim" . 8764) ("spades" . 9824) ("sub" . 8834) ("sube" . 8838)
    ("sum" . 8721) ("sup" . 8835) ("sup1" . 185) ("sup2" . 178)
    ("sup3" . 179) ("supe" . 8839) ("szlig" . 223) ("tau" . 964)
    ("there4" . 8756) ("theta" . 952) ("thetasym" . 977) ("thinsp" . 8201)
    ("thorn" . 254) ("tilde" . 732) ("times" . 215) ("trade" . 8482)
    ("uArr" . 8657) ("uacute" . 250) ("uarr" . 8593) ("ucirc" . 251)
    ("ugrave" . 249) ("uml" . 168) ("upsih" . 978) ("upsilon" . 965)
    ("uuml" . 252) ("weierp" . 8472) ("xi" . 958) ("yacute" . 253)
    ("yen" . 165) ("yuml" . 255) ("zeta" . 950) ("zwj" . 8205)
    ("zwnj" . 8204)))

;; Setup
(toplevel
  (register-cfasl-input-function *cfasl-opcode-unicode-char* #'cfasl-input-unicode-char)
  (register-cfasl-input-function *cfasl-opcode-unicode-string* #'cfasl-input-unicode-string))
