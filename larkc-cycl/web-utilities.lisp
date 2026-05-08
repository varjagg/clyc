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


;; Variables

(deflexical *http-default-accept-types* (list "text/plain" "text/html"))

(deflexical *http-informational-codes*
  "[Cyc] A-list that maps HTML Informational (1xx) status codes to
the descriptive explanation given in RFC 2616 (HTTP/1.1 specification)."
  (list (cons 100 "Continue")
        (cons 101 "Switching Protocols")))

(deflexical *http-success-codes*
  "[Cyc] A-list that maps HTML Success (2xx) status codes to the
descriptive explanation given in RFC 2616 (HTTP/1.1 specification)."
  (list (cons 200 "OK")
        (cons 201 "Created")
        (cons 202 "Accepted")
        (cons 203 "Non-Authoritative Information")
        (cons 204 "No Content")
        (cons 205 "Reset Content")
        (cons 206 "Partial Content")))

(deflexical *http-redirection-codes*
  "[Cyc] A-list that maps HTML Redirection (3xx) status codes to
the descriptive explanation given in RFC 2616 (HTTP/1.1 specification)."
  (list (cons 300 "Multiple Choices")
        (cons 301 "Moved Permanently")
        (cons 302 "Found")
        (cons 303 "See Other")
        (cons 304 "Not Modified")
        (cons 305 "Use Proxy")
        (cons 306 "(Unused)")
        (cons 307 "Temporary Redirect")))

(deflexical *http-client-error-codes*
  "[Cyc] A-list that maps HTML client error (4xx) codes to the
descriptive expectation given in RFC 2616 (HTTP/1.1 specification)."
  (list (cons 400 "Bad Request")
        (cons 401 "Unauthorized")
        (cons 403 "Forbidden")
        (cons 404 "Not Found")
        (cons 405 "Method Not Allowed")
        (cons 406 "Not Acceptable")
        (cons 407 "Proxy Authentication Required")
        (cons 408 "Request Timeout")
        (cons 409 "Conflict")
        (cons 410 "Gone")
        (cons 411 "Length Required")
        (cons 412 "Precondition Failed")
        (cons 413 "Request Entity Too Large")
        (cons 414 "Request-URI Too Long")
        (cons 415 "Unsupported Media Type")
        (cons 416 "Requested Range Not Satisfiable")
        (cons 417 "Expectation Failed")))

(deflexical *http-server-error-codes*
  "[Cyc] A-list that maps HTTP error codes to the descriptive
explanation given in RFC 2616 (HTTP/1.1 specification)."
  (list (cons 500 "Internal Server Error")
        (cons 501 "Not Implemented")
        (cons 502 "Bad Gateway")
        (cons 503 "Service Unavailable")
        (cons 504 "Gateway Timeout")
        (cons 505 "HTTP Version not supported")))

(deflexical *http-error-codes*
  (append *http-client-error-codes* *http-server-error-codes*))

(deflexical *http-status-codes*
  (append *http-informational-codes*
          *http-success-codes*
          *http-redirection-codes*
          *http-client-error-codes*
          *http-success-codes*))

(deflexical *http-get-request-template-components*
  (list (list :version "GET ~A HTTP/1.0")
        (list :connection "Connection: ~A")
        (list :user-agent "User-Agent: Cyc/~A")
        (list :host "Host: ~A~A")
        (list :accept "Accept: ")
        (list :blank-line nil)))

(deflexical *http-get-request-template-order*
  (mapcar #'first *http-get-request-template-components*))

(deflexical *http-post-request-template-components*
  (list (list :version "POST ~A HTTP/1.0")
        (list :connection "Connection: ~A")
        (list :user-agent "User-Agent: Cyc/~A")
        (list :host "Host: ~A~A")
        (list :accept "Accept: ")
        (list :cookies "Cookie: ~A")
        (list :content-type "Content-type: application/x-www-form-urlencoded")
        (list :content-length "Content-length: ~A")
        (list :blank-line nil)
        (list :query "~A")))

(deflexical *http-post-request-template-order*
  (mapcar #'first *http-post-request-template-components*))

(defparameter *trace-http-send-post-requests* nil)
(defparameter *http-cookies-to-include-in-requests* nil)

(deflexical *http-header-cookie-keyword* "Set-Cookie:")
(deflexical *http-cookie-separation-charset* (list #\;))
(deflexical *http-filtered-predefined-named-cookie-attributes*
  (list "domain" "expires" "max-age"))

(deflexical *official-uri-schemes*
  (list "aaa:" "aaas:" "acap:" "cap:" "cid:" "crid:" "data:" "dav:"
        "dict:" "dns:" "fax:" "file:" "ftp:" "go:" "gopher:" "h323:"
        "http:" "https:" "im" "imap:" "ldap:" "mailto:" "mid:" "news:"
        "nfs:" "nntp:" "pop:" "pres:" "sip:" "sips:" "snmp:" "tel:"
        "telnet:" "urn:" "wais:" "xmpp:"))

(deflexical *unofficial-uri-schemes*
  (list "about:" "aim:" "callto:" "cvs:" "ed2k:" "feed:" "fish:"
        "gizmoproject:" "iax2:" "irc:" "ircs:" "lastfm:" "ldaps:"
        "magnet:" "mms:" "msnim:" "nsfw:" "psyc:" "rsync:" "secondlife:"
        "skype:" "ssh:" "sftp:" "smb:" "sms:" "soldat:" "steam:" "tag:"
        "unreal:" "ut2004:" "webcal:" "xfire:" "ymsgr:"))

(defconstant *valid-url-beginnings*
  (list "http://" "https://" "ftp://" "gopher://" "file:" "news:" "mailto:" "anon:"))

(defconstant *url-delimiters*
  (list #\Space #\. #\, #\? #\! #\)))

(deflexical *valid-non-alphanumeric-url-chars* ";@?%/:=$-_.+!*'(),#&~")

(defparameter *require-valid-xml?* nil
  "[Cyc] If non-NIL, throw an error whenever invalid XML is detected.
@note validation is *not* exhaustive: DTDs are not checked, and in general only
basic syntax errors are detected.")


;; XML-TOKEN-ITERATOR-STATE structure
;; print-object is missing-larkc 31471 — CL's default print-object handles this.

(defstruct (xml-token-iterator-state (:conc-name "XML-IT-STATE-"))
  in-stream
  scratch-stream
  token-output-stream
  entity-map
  namespace-stack
  validate?
  resolve-entity-references?
  resolve-namespaces?
  on-deck-queue)

(defconstant *dtp-xml-token-iterator-state* 'xml-token-iterator-state)

(defparameter *xml-token-accumulator* (uninitialized))

(defparameter *cgi-host* "localhost")
(defparameter *cgi-port* 80)
(defparameter *cgi-path* "/cgi-bin/services")

(defparameter *http-header-delimiter*
  (concatenate 'string
               (string #\Return) (string #\Newline)
               (string #\Return) (string #\Newline)))

(defparameter *http-header-field-delimiters*
  (list (concatenate 'string (string #\Return) (string #\Newline))
        (make-string 1 :initial-element #\Newline)))

(deflexical *byte-order-mark-caching-state* nil)


;; Functions (declare section ordering)

;; Macro: WITH-HTTP-REQUEST
;; Reconstructed from Internal Constants evidence:
;; $list1 = ((CHANNEL MACHINE URL &KEY QUERY (METHOD :GET) (PORT :DEFAULT)
;;            (KEEP-ALIVE? T) (WIDE-NEWLINES? NIL) TIMEOUT (ACCEPT-TYPES :DEFAULT))
;;           &BODY BODY)
;; $kw3 = :ALLOW-OTHER-KEYS
;; Uses CLET, FIF, WITH-TCP-CONNECTION, SEND-HTTP-REQUEST, LIST
(defmacro with-http-request ((channel machine url &key query (method :get)
                               (port :default) (keep-alive? t) (wide-newlines? nil)
                               timeout (accept-types :default))
                              &body body)
  (let ((real-port (make-symbol "REAL-PORT")))
    `(let ((,real-port (if (eq ,port :default) 80 ,port)))
       (with-tcp-connection (,channel ,machine ,real-port
                             :access-mode :private)
         (send-http-request ,channel
                            (list :machine ,machine
                                  :url ,url
                                  :query ,query
                                  :method ,method
                                  :port ,real-port
                                  :keep-alive? ,keep-alive?
                                  :wide-newlines? ,wide-newlines?
                                  :timeout ,timeout
                                  :accept-types ,accept-types))
         ,@body))))

;; (defun http-read-request (stream &optional timeout) ...) -- active declareFunction, no body

;; (defun http-send-ok-response (stream body) ...) -- active declareFunction, no body

;; (defun http-send-error-response (stream code message) ...) -- active declareFunction, no body

;; (defun send-http-request (stream request) ...) -- active declareFunction, no body

;; (defun http-request-internal (machine port method url query keep-alive? wide-newlines? accept-types &optional timeout) ...) -- active declareFunction, no body

;; Macro: HTTP-WITH-COOKIES
;; Reconstructed from Internal Constants evidence:
;; $list44 = ((COOKIE-LIST) &BODY BODY)
;; $sym45 = *HTTP-COOKIES-TO-INCLUDE-IN-REQUESTS*
(defmacro http-with-cookies ((cookie-list) &body body)
  `(let ((*http-cookies-to-include-in-requests* ,cookie-list))
     ,@body))

;; (defun get-current-cookies-for-request () ...) -- active declareFunction, no body

;; (defun http-send-post-request (stream machine port url query keep-alive? accept-types &optional timeout) ...) -- active declareFunction, no body

;; (defun http-output-accept-types (stream accept-types format-string) ...) -- active declareFunction, no body

;; (defun http-send-get-request (stream machine port url query keep-alive? accept-types &optional timeout) ...) -- active declareFunction, no body

;; (defun http-send-response-header (stream header) ...) -- active declareFunction, no body

;; (defun http-extract-cookies-from-reply-header (header) ...) -- active declareFunction, no body

;; (defun http-compute-cookie-string-from-encoding (encoding) ...) -- active declareFunction, no body

;; (defun filter-predefined-named-cookie-attributes (attributes) ...) -- active declareFunction, no body

;; (defun http-decompose-cookie-encoding-string (string) ...) -- active declareFunction, no body

;; (defun html-url-encode (string &optional encode-equals?) ...) -- active declareFunction, no body

(defun html-url-expand-char (char)
  "[Cyc] Expand CHAR for URL encoding."
  (missing-larkc 31443))

;; (defun html-url-expand-char-including-equals (char) ...) -- active declareFunction, no body

;; (defun html-url-decode (string) ...) -- active declareFunction, no body

;; (defun html-glyph-decode (string) ...) -- active declareFunction, no body

;; (defun html-ascii-glyph-decode (string) ...) -- active declareFunction, no body

;; (defun html-ascii-glyph-p (string &optional end) ...) -- active declareFunction, no body

;; (defun html-encode-fort (fort) ...) -- active declareFunction, no body

;; (defun html-decode-fort (string) ...) -- active declareFunction, no body

;; (defun uri-p (string &optional start end official-only?) ...) -- active declareFunction, no body

(defun url-p (string)
  "[Cyc] Return T if STRING is a URL."
  (missing-larkc 31478))

;; (defun url-host (url) ...) -- active declareFunction, no body

;; (defun url-is-relative? (url) ...) -- active declareFunction, no body

;; (defun absolute-url-from-relative-url-and-base (relative-url base-url) ...) -- active declareFunction, no body

;; (defun uri-scheme-p (string &optional start end official-only?) ...) -- active declareFunction, no body

;; (defun find-url-beginning (string start end) ...) -- active declareFunction, no body

;; (defun find-url-end (string &optional start end) ...) -- active declareFunction, no body

;; (defun valid-url-char-p (char) ...) -- active declareFunction, no body

;; (defun resolve-relative-uri (base-uri relative-uri) ...) -- active declareFunction, no body

;; (defun canonicalize-relative-uri (base-uri relative-uri) ...) -- active declareFunction, no body

;; (defun remove-last-path-element (uri) ...) -- active declareFunction, no body

;; (defun uri-lacks-path-component? (uri) ...) -- active declareFunction, no body

;; (defun xml-tokenize (stream &optional validate? resolve-entity-references? resolve-namespaces?) ...) -- active declareFunction, no body

;; (defun new-xml-token-iterator (stream &optional validate? resolve-entity-references? resolve-namespaces?) ...) -- active declareFunction, no body

(defun xml-token-iterator-state-p (object)
  "[Cyc] Return T if OBJECT is an XML-TOKEN-ITERATOR-STATE."
  (missing-larkc 31509))

;; XML-IT-STATE-IN-STREAM, XML-IT-STATE-SCRATCH-STREAM, etc. — generated by defstruct
;; _CSETF-XML-IT-STATE-* — (setf xml-it-state-*) generated by defstruct

(defun make-xml-token-iterator-state (&optional arglist)
  "[Cyc] Create a new XML-TOKEN-ITERATOR-STATE."
  (declare (ignore arglist))
  (make-xml-token-iterator-state))

(defun print-xml-token-iterator-state (object stream depth)
  "[Cyc] Print an XML-TOKEN-ITERATOR-STATE."
  (declare (ignore object depth))
  (format stream "<XML-TOKEN-ITERATOR-STATE>"))

;; (defun new-xml-token-iterator-state (in-stream scratch-stream token-output-stream
                                      entity-map namespace-stack validate?
                                      resolve-entity-references? resolve-namespaces?
                                      on-deck-queue) ...) -- active declareFunction, no body

;; (defun xml-token-iterator-state-in-stream (state) ...) -- active declareFunction, no body

;; (defun xml-token-iterator-state-scratch-stream (state) ...) -- active declareFunction, no body

;; (defun xml-token-iterator-state-token-output-stream (state) ...) -- active declareFunction, no body

;; (defun xml-token-iterator-state-entity-map (state) ...) -- active declareFunction, no body

;; (defun xml-token-iterator-state-namespace-stack (state) ...) -- active declareFunction, no body

;; (defun xml-token-iterator-state-validate? (state) ...) -- active declareFunction, no body

;; (defun xml-token-iterator-state-resolve-entity-references? (state) ...) -- active declareFunction, no body

;; (defun xml-token-iterator-state-resolve-namespaces? (state) ...) -- active declareFunction, no body

;; (defun xml-token-iterator-state-on-deck-queue (state) ...) -- active declareFunction, no body

;; (defun xml-token-iterator-state-peek (state) ...) -- active declareFunction, no body

;; (defun advance-xml-token-iterator-to-next-element (state) ...) -- active declareFunction, no body

;; (defun xml-token-iterator-progress (state) ...) -- active declareFunction, no body

;; (defun make-iterator-xml-token-state (state done-fn next-fn finalize-fn) ...) -- active declareFunction, no body

;; (defun iterate-xml-token-done (state) ...) -- active declareFunction, no body

;; (defun iterate-xml-token-next (state) ...) -- active declareFunction, no body

;; (defun ensure-xml-token-on-deck-queue-populated (state) ...) -- active declareFunction, no body

;; (defun xml-iterator-state-handle-namespaces-and-entities (state token) ...) -- active declareFunction, no body

;; (defun handle-xml-namespaces (token namespace-stack validate?) ...) -- active declareFunction, no body

;; (defun xml-namespace-mapping-p (attribute) ...) -- active declareFunction, no body

;; (defun validate-xml-namespaces (token namespace-stack) ...) -- active declareFunction, no body

;; (defun maybe-validate-xml-namespace (name namespace-stack type) ...) -- active declareFunction, no body

;; (defun validate-xml-namespace (name namespace-stack type) ...) -- active declareFunction, no body

;; (defun xml-prefixed-name-p (name) ...) -- active declareFunction, no body

;; (defun xml-prefixed-name-namespace (name) ...) -- active declareFunction, no body

;; (defun xml-prefixed-name-local-name (name) ...) -- active declareFunction, no body

;; (defun xml-string-tokenize (string &optional validate? resolve-entity-references? resolve-namespaces?) ...) -- active declareFunction, no body

;; (defun xml-tokenized-http-request (machine url &optional query method port keep-alive? wide-newlines? timeout accept-types validate? resolve-entity-references?) ...) -- active declareFunction, no body

;; (defun xml-tokenized-http-request-internal (machine port method url query keep-alive? wide-newlines? accept-types timeout) ...) -- active declareFunction, no body

;; Macro: HTML-TOKENIZE
;; Reconstructed from Internal Constants evidence:
;; $list153 = (IN-STREAM)
;; $sym154 = HTML-TOKENIZE
;; $list155 = (XML-TOKENIZE)
;; Expansion: (xml-tokenize in-stream) with HTML-specific defaults
(defmacro html-tokenize (in-stream)
  `(xml-tokenize ,in-stream nil))

;; (defun xml-token-matches-exactly (token string) ...) -- active declareFunction, no body

;; (defun xml-token-matches (token string) ...) -- active declareFunction, no body

;; (defun xml-token-starts-with (token prefix) ...) -- active declareFunction, no body

(defun xml-token-mentions (token string)
  "[Cyc] Return T if TOKEN mentions STRING."
  (missing-larkc 31513))

;; (defun next-xml-token-position (tokens pattern &optional start) ...) -- active declareFunction, no body

;; (defun next-xml-token-position-if (tokens test) ...) -- active declareFunction, no body

;; (defun next-xml-token-position-if-not (tokens test) ...) -- active declareFunction, no body

;; (defun advance-xml-tokens (tokens &optional count) ...) -- active declareFunction, no body

;; (defun advance-xml-tokens-to (tokens pattern &optional start) ...) -- active declareFunction, no body

;; (defun xml-extract-token-sequence (tokens count) ...) -- active declareFunction, no body

;; (defun accumulate-xml-token (token) ...) -- active declareFunction, no body

;; (defun accumulate-xml-tokens (tokens count) ...) -- active declareFunction, no body

;; (defun accumulated-xml-tokens () ...) -- active declareFunction, no body

;; (defun xml-tokens-for-next-element (tokens) ...) -- active declareFunction, no body

;; (defun advance-xml-tokens-to-end-of-element (tokens) ...) -- active declareFunction, no body

;; (defun advance-xml-tokens-to-end-of-element-int (tokens depth) ...) -- active declareFunction, no body

;; (defun xml-declaration-p (token) ...) -- active declareFunction, no body

;; (defun xml-comment-p (token) ...) -- active declareFunction, no body

;; (defun xml-closing-tag-p (token) ...) -- active declareFunction, no body

;; (defun xml-opening-tag-p (token) ...) -- active declareFunction, no body

;; (defun advance-xml-tokens-without-crossing (tokens start-tag end-tag &optional count) ...) -- active declareFunction, no body

;; (defun xml-read (stream &optional validate? resolve-entity-references?) ...) -- active declareFunction, no body

;; (defun xml-doctype-tag-p (token) ...) -- active declareFunction, no body

;; (defun html-doctype-tag-p (token) ...) -- active declareFunction, no body

;; (defun xml-processing-instruction-p (token) ...) -- active declareFunction, no body

;; (defun entity-map-from-doctype-tag (tag) ...) -- active declareFunction, no body

;; (defun resolve-entity-references (token entity-map) ...) -- active declareFunction, no body

;; (defun resolve-predefined-xml-entities (string) ...) -- active declareFunction, no body

;; (defun remove-xml-comments (tokens) ...) -- active declareFunction, no body

;; (defun parse-xml-token (token) ...) -- active declareFunction, no body

;; (defun parse-html-token (token) ...) -- active declareFunction, no body

;; (defun parse-xml-token-int-internal (token &optional html?) ...) -- active declareFunction, no body

;; (defun parse-xml-token-int (token &optional html?) ...) -- active declareFunction, no body

;; (defun xml-attribute-value-pair-from-token (token start end attribute-start attribute-end) ...) -- active declareFunction, no body

;; (defun xml-tag? (token) ...) -- active declareFunction, no body

;; (defun regular-xml-tag? (token) ...) -- active declareFunction, no body

;; (defun xml-empty-tag? (token) ...) -- active declareFunction, no body

;; (defun xml-cdata-tag? (token) ...) -- active declareFunction, no body

;; (defun xml-cdata-tag-text (token) ...) -- active declareFunction, no body

;; (defun xml-closing-token? (token expected) ...) -- active declareFunction, no body

;; (defun xml-token-element-name? (token name) ...) -- active declareFunction, no body

;; (defun xml-token-element-name (token) ...) -- active declareFunction, no body

;; (defun xml-token-element-name-start-and-end (token) ...) -- active declareFunction, no body

;; (defun xml-tokens-to-sexpr (tokens) ...) -- active declareFunction, no body

;; (defun xml-token-iterator-to-sexpr (iterator &optional include-attributes?) ...) -- active declareFunction, no body

;; (defun xml-token-iterator-to-sexpr-internal (iterator include-attributes?) ...) -- active declareFunction, no body

;; (defun xml-tag-attribute-value (tag attribute &optional default) ...) -- active declareFunction, no body

;; (defun non-content-xml-token-p (token) ...) -- active declareFunction, no body

;; (defun get-field-value-from-xml-sexpr (sexpr field) ...) -- active declareFunction, no body

;; (defun xml-sexpr-tag (sexpr) ...) -- active declareFunction, no body

;; (defun xml-sexpr-type (sexpr) ...) -- active declareFunction, no body

;; (defun xml-sexpr-daughter (sexpr index) ...) -- active declareFunction, no body

;; (defun xml-sexpr-daughters (sexpr &optional include-text?) ...) -- active declareFunction, no body

;; (defun xml-sexpr-attributes (sexpr) ...) -- active declareFunction, no body

;; (defun xml-sexpr-attribute-value (sexpr attribute) ...) -- active declareFunction, no body

;; (defun xml-sexpr-set-attribute (sexpr attribute value) ...) -- active declareFunction, no body

;; (defun xml-sexpr-atomic-p (sexpr) ...) -- active declareFunction, no body

;; (defun get-http-status-code (header) ...) -- active declareFunction, no body

;; (defun html-redirection-header-p (header) ...) -- active declareFunction, no body

;; (defun html-redirection-url (header) ...) -- active declareFunction, no body

;; (defun parse-http-url (url) ...) -- active declareFunction, no body

;; (defun read-until-eof (stream &optional buffer-size) ...) -- active declareFunction, no body

;; (defun read-until-char (stream char &optional include-char?) ...) -- active declareFunction, no body

;; (defun read-until-one-of (stream chars &optional include-char?) ...) -- active declareFunction, no body

;; (defun slack-read-until-eof (stream &optional buffer-size) ...) -- active declareFunction, no body

;; Macro: TRY-ERROR-MESSAGE
;; Reconstructed from Internal Constants evidence:
;; $list204 = (MSG EXP &BODY BODY)
;; $sym205 = CATCH-ERROR-MESSAGE
(defmacro try-error-message (msg exp &body body)
  `(let ((,msg (catch-error-message ,exp)))
     ,@body))

;; (defun slack-read-char (&optional stream eof-error-p eof-value recursive-p) ...) -- active declareFunction, no body

;; (defun read-http-chunk (stream) ...) -- active declareFunction, no body

;; (defun write-http-chunk (stream data) ...) -- active declareFunction, no body

;; (defun http-network-terpri (stream) ...) -- active declareFunction, no body

;; (defun write-http-date (stream &optional universal-time) ...) -- active declareFunction, no body

;; (defun http-date-string (&optional universal-time) ...) -- active declareFunction, no body

;; Macro: HTML-TOKENS-FAST-FORWARD
;; Reconstructed from Internal Constants evidence:
;; $list209 = (PATTERN LIST)
;; Uses MEMBER with :test #'search, CSETQ -> setf, CDR
(defmacro html-tokens-fast-forward (pattern list)
  `(setf ,list (cdr (member ,pattern ,list :test #'search))))

;; Macro: HTML-TOKENS-STEP
;; Reconstructed from Internal Constants evidence:
;; $list212 = (LIST)
;; Uses CSETQ -> setf, CDR
(defmacro html-tokens-step (list)
  `(setf ,list (cdr ,list)))

;; Macro: HTML-TOKENS-FAST-FORWARD-TO
;; Reconstructed from Internal Constants evidence:
;; $list217 = (TOKENS TAG)
;; Uses MEMBER with :test #'search, CSETQ -> setf
(defmacro html-tokens-fast-forward-to (tokens tag)
  `(setf ,tokens (member ,tag ,tokens :test #'search)))

;; Macro: HTML-TOKENS-FAST-FORWARD-PAST
;; Uses HTML-TOKENS-FAST-FORWARD
(defmacro html-tokens-fast-forward-past (tokens tag)
  `(html-tokens-fast-forward ,tag ,tokens))

;; Macro: HTML-TOKENS-EXTRACT-CURR
;; Reconstructed from Internal Constants evidence:
;; $sym216 = CAR
(defmacro html-tokens-extract-curr (list)
  `(car ,list))

;; (defun is-html-terminating-tag? (token tag) ...) -- active declareFunction, no body

;; (defun test-for-html-tag? (tokens tag) ...) -- active declareFunction, no body

;; Macro: HTML-CONSUME-STARTING-TAG
;; Reconstructed from Internal Constants evidence:
;; $list217 = (TOKENS TAG)
;; Uses HTML-TOKENS-EXTRACT-CURR, STRING-EQUAL, ERROR, HTML-TOKENS-STEP
(defmacro html-consume-starting-tag (tokens tag)
  (let ((marker (make-symbol "MARKER")))
    `(let ((,marker (html-tokens-extract-curr ,tokens)))
       (unless (string-equal ,tag ,marker)
         (error "Invalid input file format. Expected starting ~S and received ~S.~%"
                ,tag ,marker))
       (html-tokens-step ,tokens))))

;; Macro: HTML-CONSUME-CLOSING-TAG
;; Reconstructed from Internal Constants evidence:
;; Uses IS-HTML-TERMINATING-TAG?, ERROR, HTML-TOKENS-STEP
(defmacro html-consume-closing-tag (tokens tag)
  (let ((marker (make-symbol "MARKER")))
    `(let ((,marker (html-tokens-extract-curr ,tokens)))
       (unless (is-html-terminating-tag? ,marker ,tag)
         (error "Invalid input file format. Expected closing ~S and received ~S.~%"
                ,tag ,marker))
       (html-tokens-step ,tokens))))

;; Macro: HTML-EXTRACT-TAG-CONTENT
;; Reconstructed from Internal Constants evidence:
;; $list228 = (TOKENS TAG STORAGE)
;; Uses PROGN, HTML-CONSUME-STARTING-TAG, setf, HTML-TOKENS-EXTRACT-CURR,
;;      HTML-TOKENS-STEP, HTML-CONSUME-CLOSING-TAG
(defmacro html-extract-tag-content (tokens tag storage)
  `(progn
     (html-consume-starting-tag ,tokens ,tag)
     (setf ,storage (html-tokens-extract-curr ,tokens))
     (html-tokens-step ,tokens)
     (html-consume-closing-tag ,tokens ,tag)))

;; Macro: HTML-EXTRACT-POSSIBLY-EMPTY-TAG-CONTENT
;; Reconstructed from Internal Constants evidence:
;; $list232 = (TOKENS TAG STORAGE &OPTIONAL (DEFAULT NIL))
;; Uses TEST-FOR-HTML-TAG?, HTML-EXTRACT-TAG-CONTENT
(defmacro html-extract-possibly-empty-tag-content (tokens tag storage &optional (default nil))
  `(if (test-for-html-tag? ,tokens ,tag)
       (html-extract-tag-content ,tokens ,tag ,storage)
       (setf ,storage ,default)))

;; Macro: HTML-POSSIBLY-EXTRACT-TAG-CONTENT
;; Reconstructed from Internal Constants evidence:
;; Uses PWHEN -> when, TEST-FOR-HTML-TAG?, HTML-EXTRACT-TAG-CONTENT
(defmacro html-possibly-extract-tag-content (tokens tag storage)
  `(when (test-for-html-tag? ,tokens ,tag)
     (html-extract-tag-content ,tokens ,tag ,storage)))

;; (defun html-file-as-tokens (filename) ...) -- active declareFunction, no body

;; (defun html-stream-as-tokens (stream) ...) -- active declareFunction, no body

;; (defun html-cleaned-token-string (token) ...) -- active declareFunction, no body

;; (defun html-property-list-to-url-parameters (plist) ...) -- active declareFunction, no body

;; (defun clear-byte-order-mark () ...) -- active declareFunction, no body

;; (defun remove-byte-order-mark () ...) -- active declareFunction, no body

;; (defun byte-order-mark-internal () ...) -- active declareFunction, no body

;; (defun byte-order-mark () ...) -- active declareFunction, no body

;; (defun http-response-header (response) ...) -- active declareFunction, no body

;; (defun http-response-body (response) ...) -- active declareFunction, no body

;; (defun parse-http-response (response) ...) -- active declareFunction, no body

;; (defun http-format-query (query) ...) -- active declareFunction, no body

;; (defun html-encode-sexpr (sexpr) ...) -- active declareFunction, no body

;; (defun http-retrieve (machine port url query &optional method keep-alive? wide-newlines? accept-types) ...) -- active declareFunction, no body

;; (defun http-retrieve-via-redirection (url &optional max-redirections current-count) ...) -- active declareFunction, no body

;; (defun get-html-source-from-url (url &optional max-redirections accept-types) ...) -- active declareFunction, no body

;; (defun dereference-url (url file &optional max-redirections accept-types) ...) -- active declareFunction, no body

;; (defun save-url-to-file (url file &optional max-redirections accept-types) ...) -- active declareFunction, no body


;; Setup phase

;; [Clyc] Java setup invokes (define_test_case_table_int ...) here, but
;; new-generic-test-case-table's check-types call missing-larkc stubs
;; test-case-name-p and cyc-test-kb-p, so the call cannot run at load time.
;; Restore once those predicates have bodies.
(note-funcall-helper-function 'print-xml-token-iterator-state)
(note-funcall-helper-function 'iterate-xml-token-done)
(note-funcall-helper-function 'iterate-xml-token-next)
(register-external-symbol 'xml-tokenized-http-request)
(note-memoized-function 'parse-xml-token-int)
(note-globally-cached-function 'byte-order-mark)
;; [Clyc] Java setup also invokes (define_test_case_table_int ...) for
;; xml-tokens-to-sexpr, parse-html-token, and parse-xml-token, but the
;; new-generic-test-case-table check-types depend on missing-larkc stubs
;; (test-case-name-p, cyc-test-kb-p) so they cannot run at load time.
