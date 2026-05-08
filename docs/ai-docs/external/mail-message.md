# Mail message

A simple **outbound email** library: build a multipart message with from/to/cc/bcc/subject/headers/parts, then deliver it via SMTP. Cyc agents can use this to email a Cyclist when something happens — alerts, batch results, KE notifications.

The implementation is `mail-message.lisp`. **Sending is missing-larkc** — `send-message`, `send-message-internal`, `send-message-part`, `send-message-parts`, `send-message-part-headers`, `send-message-part-data`, `validate-message`. The **construction API is fully ported** — every accessor, mutator, and constructor for `message` and `message-part` works in the running image. So you can build a message; you just can't send one without re-implementing the SMTP path.

There are no callers anywhere else in the codebase — this is an entirely self-contained module that only exposes the constructors. In the LarKC port no Cyc operation actually emails anyone.

## What problem does it solve

Cyc agents (background tasks, KE event handlers, query result reporters) sometimes want to email a human. Without an in-process SMTP client, the Cyc process would have to shell out to `sendmail` or `mailx`. This module gives Cyc its own SMTP-speaking client so it can do delivery from inside the Lisp image.

The module is **outbound-only** — no inbox parsing, no IMAP, no POP3. The complexity is all in the wire-format generation: MIME multipart boundaries, content-type / disposition headers, attachment encoding.

## Data structures

### `message` (defstruct, conc-name `MSG-`)

| Slot | Type | Meaning |
|---|---|---|
| `from` | string | RFC 5322 `From:` header value (one address). |
| `to` | list of string | `To:` recipients. |
| `cc` | list of string | `Cc:` recipients. |
| `bcc` | list of string | `Bcc:` recipients (delivery only, never appears in headers). |
| `subject` | string | `Subject:` header. |
| `additional-headers` | list of string | Arbitrary extra headers (each a complete `Name: value` line). |
| `host` | string | SMTP server hostname. Defaults to `"localhost"` in `new-message`. |
| `port` | integer | SMTP server port. nil means SMTP default (25). |
| `parts` | list of `message-part` | MIME parts; the email body. |

The `to`/`cc`/`bcc` slots are **lists** even when there's a single recipient — `new-message` wraps a single string into a one-element list, and `message-add-{to,cc,bcc}` appends. There's no facility for parsing a comma-separated list back into individual addresses; the API is list-of-strings throughout.

`additional-headers` is a list-of-strings rather than a key/value alist. The format is "you write the whole line as one string." This is convenient for `Reply-To: foo@bar.com` style headers but doesn't help with multi-line headers; a clean rewrite should use a proper header struct.

### `message-part` (defstruct, conc-name `MSG-PART-`)

| Slot | Type | Meaning |
|---|---|---|
| `content-type` | string | MIME type, e.g. `"text/plain"`, `"image/jpeg"`. Default `"text/plain"`. |
| `content-type-parameters` | alist | Extra params on `Content-Type`, e.g. `((:charset . "utf-8"))`. |
| `disposition` | string | `"inline"` or `"attachment"`. |
| `content-disposition-parameters` | alist | Extra params on `Content-Disposition`, e.g. `((:filename . "report.pdf"))`. |
| `encoding` | string | `"7bit"`, `"8bit"`, or `"binary"`. Note: NOT `"base64"` or `"quoted-printable"` — see "Encoding limitations" below. |
| `data` | string | The part body OR a filename if `data-type` is `:file`. |
| `data-type` | keyword | `:string` (data is the literal body) or `:file` (data is a path; reader streams from disk). |

The `:string` vs `:file` distinction is the file-attachment story: with `:file`, the sender opens the path and streams its bytes into the SMTP connection rather than holding the whole content in memory. The constructor `new-message-attachment` defaults to `:file`, and `new-inline-message-part` defaults to `:string`.

`valid-message-part-data-type-p` enforces the `(:string :file)` enum. `valid-message-part-encoding-p` enforces `("7bit" "8bit" "binary")`.

## API surface (what survived)

### Message constructors / mutators

| Function | Use |
|---|---|
| `make-message &optional arglist` | Empty message; arglist is ignored (legacy keyword-args entry point). |
| `new-message &optional from to subject host port cc` | Build a message in one call; sets `to`/`cc` as one-element lists. |
| `message-set-{from,subject,host,port}` / `message-{from,subject,host,port}` | Direct slot accessors with friendlier names. |
| `message-add-{to,cc,bcc}` / `message-{to,cc,bcc}` | Append a recipient; access the full list. |
| `message-add-header` / `message-additional-headers` | Append a raw header string. |
| `message-add-part` / `message-parts` | Append a `message-part`; access the full list. |

The `message-set-*` and `message-{slot}` wrappers are thin: they call the defstruct's accessor with a friendlier name. A clean rewrite can drop the wrappers and use the defstruct accessors directly.

### Part constructors

| Function | Use |
|---|---|
| `new-inline-message-part data &optional content-type encoding` | Body part, defaults `text/plain` `7bit`, data-type `:string`. |
| `new-message-attachment filename &optional content-type encoding data-type` | Attachment part, defaults `text/plain` `7bit`, data-type `:file`. |
| `new-message-part content-type disposition encoding data data-type` | The five-arg primitive constructor. |
| `message-part-set-attachment-name part name` | Sets `:filename` content-disposition param. |
| `message-part-set-content-disposition-parameter part key value` | Generic param setter (does dedup). |

The disposition-param setter is the cleanest accessor in the file: cons the new pair onto the alist after removing any prior entry with the same key. This dedup pattern is used implicitly throughout — there's no equivalent for `content-type-parameters` because `valid-message-part-encoding-p` is the only validator.

### Predicates / hashing

| Function | Status |
|---|---|
| `message-p` / `message-part-p` | Working (typep). |
| `valid-message-part-data-type-p` / `valid-message-part-encoding-p` | Working enum check. |
| `sxhash-message-method` / `sxhash-message-part-method` | `missing-larkc 29965` / `29966` — port-time placeholder. |
| `sxhash-message` / `sxhash-message-part` | Stripped — would have been the dispatch layer over the method. |

The two sxhash methods are the only `missing-larkc` entries among the working bodies; everything else is either fully ported or commented stubs.

### Print methods

`print-object` is implemented as a `defmethod` on the `message` and `message-part` classes. Both produce simple `<MESSAGE>` and `<MESSAGE-PART (content-type)>` debug strings — the original Java had `print-message` / `print-message-part` defuns that were inlined into the defmethod at port time.

## What's missing — the entire send path

| Stripped function | Signature | What it would do |
|---|---|---|
| `send-message message &optional verbose?` | top-level entry; opens SMTP connection, returns success/failure |
| `send-message-internal message verbose?` | actual MIME assembly + SMTP transcript driver |
| `send-message-parts message stream` | iterate parts, write boundaries |
| `send-message-part part boundary stream` | write one part with its boundary marker |
| `send-message-part-headers part stream` | emit `Content-Type:`, `Content-Disposition:`, `Content-Transfer-Encoding:` |
| `send-message-part-data part stream` | emit body (string-direct or file-streamed) |
| `validate-message message` | check from/to/host invariants before sending |

A clean rewrite needs all of these. The construction API is solid; the wire-format generation and SMTP I/O is a normal-shaped piece of work — open TCP socket to host:port, run SMTP transcript (HELO / MAIL FROM / RCPT TO / DATA / quit), in DATA emit headers + multipart body with `--<boundary>` separators.

## Encoding limitations

The valid-encoding enum is `("7bit" "8bit" "binary")` only. There's no `"base64"` or `"quoted-printable"`. This means the original module **does not handle binary attachments correctly** in the general case — non-ASCII or non-text data has to either be passed through `8bit` (requires the SMTP server to advertise 8BITMIME) or `binary` (requires CHUNKING / BDAT). For typical PDF / image attachments to legacy SMTP servers, base64 is required. A clean rewrite must extend the enum and add an encoder.

The existing `data-type :file` path also doesn't apply any encoding to file contents — it's a raw byte stream, which means the file's bytes go through the SMTP DATA command verbatim. This is correct for `8bit` / `binary` and broken for `7bit`.

## When does mail get sent?

In the LarKC port: **never**. There are no callers of any function in this file. The module is dormant.

In the full Cyc engine: probably triggered by KE event handlers ("a constant was killed, notify the responsible Cyclist"), batch-job completion notifications, or scheduled-task error reporters. The empty caller graph means the design intent is recoverable only from the API surface.

## Notes for a clean rewrite

- **Use a real mail library.** `cl-smtp`, JavaMail, Python `email.message` + `smtplib` — every host language has a mature option. Don't rewrite SMTP from scratch.
- **Keep the data model — drop the API.** The `message` / `message-part` structs are a clean spec for "what does a sendable email contain." Use them as the input shape to the host's mail library, but don't preserve the sixteen `message-X` / `message-set-X` wrappers; the defstruct's auto-generated accessors are enough.
- **The `data-type :string` / `:file` split is correct** — large attachments shouldn't be in memory. Keep this pattern.
- **The encoding enum is incomplete.** Add `"base64"` and `"quoted-printable"`. Add automatic encoding selection: text → 7bit if ASCII else quoted-printable; binary → base64 unconditionally. Drop the bare `"binary"` option unless the host's SMTP library negotiates CHUNKING.
- **`additional-headers` should be `(name . value)` pairs**, not raw strings. The current design forces the caller to know SMTP folding rules; a struct-of-pairs lets the library handle them.
- **`new-message` defaults `host` to `"localhost"`** which is friendly but probably wrong for most deployments. Make it nil-by-default and require a config; localhost is rarely a real SMTP server in 2026.
- **No retry / backoff.** A clean rewrite should at minimum surface delivery errors back to the caller; ideally have a queue with retries.
- **No DKIM, no SPF, no DMARC.** The original is a 2009-era SMTP client with none of the modern auth. A clean rewrite emitting on behalf of a real domain needs all three.
- **No SMTPS / STARTTLS.** Port 25 plaintext only. A clean rewrite needs at minimum STARTTLS.
- **No async / no streaming on output.** The current `send-message-parts` (stripped) presumably wrote to the SMTP stream synchronously; that's fine for low-volume but pins a thread per delivery. Use the host's async I/O.
- **`new-inline-message-part` and `new-message-attachment` are constructor sugar** — keep them; they're the right API for callers that don't want to remember which slots correspond to inline-vs-attached.
- **`sxhash-message-method` is missing-larkc 29965.** A clean rewrite probably doesn't need a per-message sxhash at all — sxhashing emails is a strange thing to do unless they're being deduped in some cache that no longer exists.
- **No multipart/alternative or multipart/related** — the current `parts` slot is a flat list; nested multipart structures (HTML + plaintext alternative; HTML + inline images) need a recursive part type. Easy extension.
- **The Bcc handling depends on `send-message-internal`** (stripped). A clean rewrite must not emit `Bcc:` in the message headers — only as RCPT TO during SMTP. Worth marking explicitly because forgetting this is a privacy bug.
