# Web utilities

The all-in-one **HTTP client + XML/HTML parser + URL utilities** module. Provides the live wire (HTTP GET/POST over TCP, cookies, chunked transfer, redirection following) and the pull-style XML/HTML token iterator that consumers walk to extract data from a fetched page.

The implementation is `web-utilities.lisp` (706 lines, the largest in this category). **The function bodies are mostly missing-larkc** — about 95 of ~110 declared functions have no body. What survived:

- 13 macros, all reconstructed from Internal Constants evidence (the HTTP request macro, cookie scoping, HTML token-stream walking, XML/HTML tokenize wrappers, error-message try).
- The `xml-token-iterator-state` defstruct and one `print-object` defmethod.
- A few `missing-larkc` placeholder bodies (`url-p`, `xml-token-iterator-state-p`, `xml-token-mentions`, `html-url-expand-char`).
- ~30 lexicals: HTTP status code tables, request templates, official/unofficial URI schemes, URL delimiters, cookie defaults.
- Setup-phase registration of `xml-tokenized-http-request` as a Cyc API symbol.

The data tables (status codes, URI schemes, request templates) are the most useful surviving artifacts — they document the wire-protocol shape that the stripped functions implement.

## What this is for

Cyc's web access — fetch HTML or XML from a URL, parse it, walk the tokens. Used by code that wants to:

- Pull content from a website into the KB (knowledge import from external sources).
- Make a SOAP / REST call to an external service.
- Drive a CGI handler — Cyc itself acts as the server (`*cgi-host*`/`*cgi-port*`/`*cgi-path*` parameters).
- Render query results as HTML (combined with `xml-utilities.lisp`).

Two entire complete-on-paper subsystems live here:
1. **HTTP client/server** — `with-http-request`, `send-http-request`, cookies, chunked transfer encoding, redirection.
2. **XML/HTML token iterator** — pull-style tokenizer over a stream, with namespace stack, entity-reference resolution, validate? mode, and "on-deck queue" for one-token lookahead.

## Data tables (these survived)

### HTTP status codes

Each class of status codes is a separate alist deflexical, then merged into combined ones:

| Variable | Range | Use |
|---|---|---|
| `*http-informational-codes*` | 100, 101 | 1xx (Continue, Switching Protocols) |
| `*http-success-codes*` | 200–206 | 2xx |
| `*http-redirection-codes*` | 300–307 | 3xx |
| `*http-client-error-codes*` | 400–417 | 4xx |
| `*http-server-error-codes*` | 500–505 | 5xx |
| `*http-error-codes*` | 4xx + 5xx | client + server errors merged |
| `*http-status-codes*` | all | informational + success + redirection + client-error + (success again — apparent bug, server-error missing) |

The bug in `*http-status-codes*` (uses `*http-success-codes*` twice instead of also `*http-server-error-codes*`) is preserved from the original. A clean rewrite must either fix or note this — server-error 5xx codes won't lookup against `*http-status-codes*`.

The format throughout: `(cons CODE-INTEGER "Description String")`. Used for friendly error reporting, not for control flow — the actual handlers presumably switch on numeric ranges.

### Request templates

The HTTP request line and headers are parameterized by template alists:

```
*http-get-request-template-components*
  ((:version "GET ~A HTTP/1.0")
   (:connection "Connection: ~A")
   (:user-agent "User-Agent: Cyc/~A")
   (:host "Host: ~A~A")
   (:accept "Accept: ")
   (:blank-line nil))

*http-post-request-template-components*  ; same plus :cookies, :content-type, :content-length, :query
```

Each entry is `(:tag format-string)`. The order list (`*http-get-request-template-order*`, `*http-post-request-template-order*`) controls emission order — this lets the post template insert cookies/content-type/content-length/blank-line/query in the right spots.

`HTTP/1.0` is hardcoded — no chunked transfer on requests, only on responses (the stripped `read-http-chunk` / `write-http-chunk` are HTTP/1.1 chunked-encoding helpers, presumably for response handling). A clean rewrite should target HTTP/1.1+ on both sides.

### URI schemes

`*official-uri-schemes*` (36 entries) lists IANA-registered schemes: `http`, `https`, `ftp`, `mailto`, `urn`, `dns`, `ldap`, `xmpp`, etc. `*unofficial-uri-schemes*` (33 entries) lists popular non-registered ones: `aim`, `magnet`, `skype`, `secondlife`, `steam`, `ymsgr`, etc. Used by the stripped `uri-scheme-p` to validate scheme strings.

Both lists include the trailing `:`. The handful of `:`-less entries (`im`) appears to be a typo in the original — every other entry has the colon. A clean rewrite should standardize.

`*valid-url-beginnings*` is a different list — eight specific full-prefix strings (`"http://"`, `"file:"`, `"mailto:"`, etc.) that `find-url-beginning` (stripped) uses to detect a URL embedded in plain text. The `"anon:"` scheme is a Cyc-internal one; everything else is standard.

`*valid-non-alphanumeric-url-chars*` is the string `";@?%/:=$-_.+!*'(),#&~"` — the punctuation legal in URL paths/queries per RFC 3986.

`*url-delimiters*` is the list of chars that *terminate* a URL in surrounding text: space, period, comma, question, exclamation, close-paren. Used by `find-url-end` (stripped) to identify the end of a URL embedded in a sentence.

### Cookies

| Variable | Default | Use |
|---|---|---|
| `*http-cookies-to-include-in-requests*` | nil | Bound by `http-with-cookies` macro to a list of cookies for outbound requests. |
| `*http-header-cookie-keyword*` | `"Set-Cookie:"` | Header name to recognize on responses. |
| `*http-cookie-separation-charset*` | `(#\;)` | Char(s) that separate multiple cookies in a header. |
| `*http-filtered-predefined-named-cookie-attributes*` | `("domain" "expires" "max-age")` | Attribute names that are *cookie metadata*, not actual values — `filter-predefined-named-cookie-attributes` (stripped) uses this to strip them when extracting actual cookie value pairs. |

### CGI defaults

```
*cgi-host*  "localhost"
*cgi-port*  80
*cgi-path*  "/cgi-bin/services"
```

Defaults for when Cyc acts as a CGI server. There's no actual CGI handler in this file — these parameters are just defaults that some other system (presumably stripped) consumes. The `services` path suggests CGI was the dispatch endpoint for the API services ([java-c-name-translation-and-backends.md](java-c-name-translation-and-backends.md) covers the related Java-API kernel).

### Header / line delimiters

```
*http-header-delimiter*  = "\r\n\r\n"        (end-of-headers marker)
*http-header-field-delimiters*  = ("\r\n" "\n")  (line-end variants — accepts both)
```

Standard HTTP framing.

### XML state

```
*xml-token-accumulator*  (uninitialized)         ; thread-local? - the macro that uses it is stripped
*byte-order-mark-caching-state*  nil             ; caches the BOM bytes for stream-encoding detection
*require-valid-xml?*  nil                        ; if t, signal error on invalid XML during tokenize
```

The `*require-valid-xml?*` mode is interesting — it's an opt-in strict-XML check, but the docstring warns "validation is *not* exhaustive: DTDs are not checked, and in general only basic syntax errors are detected." This is a 2009-era pragmatic compromise; a clean rewrite should defer to a real XML parser that does proper DTD/Schema validation.

## Data structure: `xml-token-iterator-state`

```
(defstruct (xml-token-iterator-state (:conc-name "XML-IT-STATE-"))
  in-stream                       ; underlying byte stream
  scratch-stream                  ; intermediate buffer for one-token assembly
  token-output-stream             ; where assembled tokens get queued
  entity-map                      ; current DOCTYPE-defined entities (alist or hashtable)
  namespace-stack                 ; xmlns: bindings, depth-stacked
  validate?                       ; bool: tokenize in strict mode
  resolve-entity-references?      ; bool: expand &amp; etc. inline
  resolve-namespaces?             ; bool: rewrite prefixed names to {URI}localname form
  on-deck-queue)                  ; one-token lookahead buffer
```

This is the heart of the XML pull parser. The `iterator` style means the consumer calls `advance-xml-token-iterator-to-next-element` (stripped) repeatedly, getting one token at a time, with the option to `peek` (also stripped) without consuming. The `on-deck-queue` is the lookahead buffer that supports `peek`.

The four boolean flags are independent toggles:
- `validate?` — strict/lax mode.
- `resolve-entity-references?` — whether to expand named/numeric entities inline (`&amp;` → `&`).
- `resolve-namespaces?` — whether to rewrite `prefix:name` into `{namespace-URI}name` Clark-notation.

The `entity-map` is populated from any `<!DOCTYPE ... [...] >` declaration encountered at the start of the stream (`entity-map-from-doctype-tag` — stripped).

The `namespace-stack` is a stack-of-alists: every element open pushes the new `xmlns:` declarations from its attributes, every close pops. Handling done by `handle-xml-namespaces` / `validate-xml-namespaces` / `validate-xml-namespace` (all stripped).

## The 13 reconstructed macros

The macros are the system's user-visible API. With function bodies stripped, these are essentially the only direct invocation paths surviving:

### `with-http-request`

```
(with-http-request (channel machine url
                    &key query (method :get) (port :default)
                    (keep-alive? t) (wide-newlines? nil)
                    timeout (accept-types :default))
  body...)
```

The top-level HTTP-client API: open a TCP connection to `machine:port`, send an HTTP request with `url` / `method` / `query`, then run `body` with `channel` bound to the connection's stream. Default port is 80; ports `:default` resolves to 80.

The macro expands to `with-tcp-connection` (from `tcp.lisp`) → `send-http-request` → body. A clean rewrite preserves this nesting: connection management is one concern, request-formatting is another.

### `http-with-cookies`

```
(http-with-cookies (cookie-list) body...)
```

Binds `*http-cookies-to-include-in-requests*` to `cookie-list` so any HTTP request issued from inside `body` carries them.

### `html-tokenize`

```
(html-tokenize in-stream)  ; expands to (xml-tokenize in-stream nil)
```

Just a thin wrapper around `xml-tokenize` with `validate?` set to nil. HTML is XML-with-validate-off.

### `try-error-message`

```
(try-error-message msg exp body...)
```

Catches an error from evaluating `exp`; if one occurred, `msg` is bound to its message string and `body` runs. Equivalent to `(let ((msg (catch-error-message exp))) body...)`. A general-purpose error-handling sugar that ended up in the web-utilities file presumably because so much of the HTTP code uses it.

### HTML token-stream macros (six)

```
(html-tokens-fast-forward pattern list)        ; advance list past first member containing pattern
(html-tokens-fast-forward-to tokens tag)       ; advance to (not past) tag
(html-tokens-fast-forward-past tokens tag)     ; advance past tag
(html-tokens-step list)                        ; (cdr list)
(html-tokens-extract-curr list)                ; (car list)
(html-consume-starting-tag tokens tag)         ; expect-and-step the open tag, error if not match
(html-consume-closing-tag tokens tag)          ; expect-and-step the close tag
(html-extract-tag-content tokens tag storage)  ; consume <tag> ... </tag>, store inner in storage
(html-extract-possibly-empty-tag-content tokens tag storage &optional (default nil))
(html-possibly-extract-tag-content tokens tag storage)
(test-for-html-tag? tokens tag)                ; (function, declareFunction stripped) — peek if curr matches
```

These are imperative, mutating macros — they assume `tokens` is a place that can be `setf`'d. The walker style is "walk a list of tokens, mutating the list pointer as you go." This is a strange DSL — neither pull-iterator (the `xml-token-iterator-state` style) nor functional (no recursion). It's optimized for screen-scraping HTML-extraction loops written in a specific procedural style.

A clean rewrite should pick *one* style: either an iterator with `next` / `peek` / `consume` methods, or pure functions over an immutable token list. The current "macros that mutate the list-place" mix is awkward and error-prone (the `consume-starting-tag` error path leaves the list pointer in an indeterminate state).

## When does an HTTP request happen?

Callers in the LarKC port: there are none. No file invokes `with-http-request` or any of the request functions. The `xml-tokenized-http-request` API entry point is registered but unreachable.

In the full Cyc engine, the implied callers are:
1. **Cyc fetcher tools** — HTTP GET an external page, tokenize it, look for KB-relevant content.
2. **Web-services API** — HTTP POST a query result to a callback URL.
3. **CGI handler** — accept HTTP requests on the `*cgi-host*:*cgi-port*` port.

The fact that none of them exist in the LarKC port means the web layer is a *latent* capability — the wire format and templates are all here, but no application uses them.

## Cyc-API registration

```
(register-external-symbol 'xml-tokenized-http-request)
```

The single API entry point exposed: `xml-tokenized-http-request machine url &optional query method port keep-alive? wide-newlines? timeout accept-types validate? resolve-entity-references?`. Argument signature shows the merge of HTTP-request and XML-tokenize concerns — fetch a URL and get back a tokenizer that yields XML elements from the response body. This is the primary intended use case: scrape an external XML feed.

## Notes for a clean rewrite

- **Do not rewrite an HTTP client.** Use the host language's stdlib (`requests` in Python, `OkHttpClient` in Java, `cl-http`/`drakma` in CL). The stripped HTTP code here is HTTP/1.0 with manual cookie handling — even if it had bodies, it'd be obsolete. The status-code tables are useful as a reference but not as code.
- **Do not rewrite an XML parser.** Use a real one (libxml2, host stdlib). The `xml-token-iterator-state` is a 2009-era pull parser; modern libraries do this better with proper schema/DTD support and faster I/O.
- **Keep the URI scheme tables and the URL char-classes** as constants — they're still correct and not worth re-deriving.
- **The HTTP request-template alists are a surprisingly clean DSL** for "describe how to assemble an HTTP/1.0 request line by line." If you keep building from the templates, fix the bug where `*http-status-codes*` doubles `*http-success-codes*` instead of including server errors.
- **Replace the imperative `html-tokens-X` macros with a real iterator.** A clean rewrite gets `iterator.next()` / `iterator.peek()` / `iterator.consume(tag)` and drops the `setf`-on-place style entirely.
- **The four iterator-state booleans should be a flags struct or a bitmask** — three of them combine to mean "what kind of XML?" and a clean rewrite can preset configurations (`html-config`, `strict-xml-config`, `webservice-config`) rather than ask the caller to set four bools.
- **Drop the Cyc-as-CGI parameters** (`*cgi-host*`/`*cgi-port*`/`*cgi-path*`). CGI was already a legacy protocol in 2009; in 2026 it's dead. A clean rewrite should expose Cyc as a real HTTP service (HTTPS, JSON-RPC or REST) instead.
- **The `html-tokenize` → `xml-tokenize` thunk is right** — HTML is permissive XML for these purposes. Keep the simplification. But for *real* HTML parsing (HTML5 with optional close tags, implicit `<tbody>`, etc.) you need a proper HTML parser that handles the HTML5 tokenizer state machine, not an XML parser with validate-off.
- **The cookie code is from a different decade.** Modern cookies have HttpOnly, Secure, SameSite, Partitioned flags. The `domain`/`expires`/`max-age` filter list is incomplete. A clean rewrite must handle modern cookie semantics or skip cookies entirely (use OAuth tokens / Bearer auth).
- **The `*xml-token-accumulator*` global** is from a stripped macro that buffered tokens during a parse session. Without the macro it's dead; in a clean rewrite, accumulation is per-iterator-state, not global.
- **`*byte-order-mark-caching-state*` is a globally-cached function result** (per `(note-globally-cached-function 'byte-order-mark)`). It caches the BOM detected at start of stream so subsequent streams that share encoding can skip detection. This is a micro-optimization not worth keeping in a clean rewrite.
- **The "wide-newlines?" parameter** on `with-http-request` is to support clients/servers that emit `\r\n\r\n` vs `\n\n` for header termination. RFC says `\r\n` only, but real-world is messy. Keep this configurable, default to lenient (accept both).
- **The `parse-http-url`, `url-host`, `url-is-relative?`, `absolute-url-from-relative-url-and-base` family is missing** but trivially implementable. Use the host's URL/URI library; do not parse strings by hand.
- **`get-html-source-from-url`, `dereference-url`, `save-url-to-file`** — these are convenience wrappers that fetch a URL and either return the body, dereference redirects, or save to a file. Keep the API names — they're well-shaped.
- **`http-retrieve-via-redirection url &optional max-redirections current-count`** — manual redirect handling with hop count. A clean rewrite should set `max-redirections` to 5 by default and put a hard cap to prevent loops.
