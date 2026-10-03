# XMPP `xml:lang` Enforcement Findings (ejabberd + xmpp)

## Scope
This documents how ProcessOne `xmpp` + `ejabberd` handle invalid `xml:lang`, including:
- where validation is applied,
- when the stream is closed vs stanza-level error,
- enforcement start date/commit,
- likely first `ejabberd` release containing it,
- exhaustive built-in element set validated with `xmpp_lang:check`.

## Validation Mechanism
- Validator function: `xmpp_lang:check/1`
  - File: [`xmpp/src/xmpp_lang.erl`](https://github.com/processone/xmpp/blob/master/src/xmpp_lang.erl)
  - Behavior: returns input if valid, throws `{bad_lang, Value}` if invalid.
- Parser/grammar backend:
  - [`xmpp/c_src/xmpp_lang.rl`](https://github.com/processone/xmpp/blob/master/c_src/xmpp_lang.rl)
  - [`xmpp/c_src/lang.rl`](https://github.com/processone/xmpp/blob/master/c_src/lang.rl)
  - Grammar is enforced in NIF (`xmpp_lang`), from generated Ragel rules.

## How Validation Is Applied
Validation is explicit per codec field, not global for every XML attribute.
The source of truth is `xmpp/specs/xmpp_codec.spec`, where `xml:lang` attrs with
`dec = {xmpp_lang, check, []}` are validated.

### Exhaustive built-in element set validated for `xml:lang`
From `xmpp/specs/xmpp_codec.spec`:
- `stream_start`
- `iq`
- `message`
- `message_body`
- `message_subject`
- `presence`
- `presence_status`
- `error_text`
- `stream_error_text`
- `sasl_failure_text`
- `disco_identity`
- `adhoc_command`
- `jingle_reason_text`
- `jingle_ft_desc`
- `report_text`

Notes:
- This is exhaustive for built-in generated codec elements.
- Unknown or ignored extension elements are not necessarily validated unless their decoder explicitly uses `xmpp_lang:check`.

## Runtime Behavior: Disconnect vs Non-Disconnect
Inbound processing happens in `xmpp_stream_in`.

### Stream start (`<stream:stream ...>`) path
- Event: `xmlstreamstart`.
- Decode failures (`{xmpp_codec, Why}`), including bad `xml:lang` on stream start, are converted to `stream:error` `invalid-xml`.
- Sending a `#stream_error{}` triggers stream close.

Consequence:
- Invalid `xml:lang` on top stream element causes stream error + disconnect.

### Stanza/element (`xmlstreamelement`) path
- Event: `xmlstreamelement`.
- Decode failures go through `process_invalid_xml/3`.
- If incoming element is a stanza (`iq/message/presence`), server sends stanza `bad-request` and does **not** close stream.
- For some non-stanza protocol elements (e.g., SASL auth/response/abort), server sends protocol failure (e.g., SASL malformed-request), not stream close.

Consequence:
- Invalid `xml:lang` on validated stanza-level or validated child elements is generally stanza/protocol-level failure, not connection drop.

## Extra Policy: Long Stream `xml:lang`
`xmpp_stream_in` has a separate rule for client stream start:
- if `size(Lang) > 35` on stream start, send `policy-violation` stream error.
- this causes disconnect (because it is a stream error).

## Enforcement Start (Git)
### Core enforcement commit in `xmpp`
- Commit: `f6cb9a194126049fa0d562d720fd4489e7446be2`
- Date: `2018-11-23T11:50:39+03:00`
- Subject: `Validate xml:lang attribute according to RFC5234`

### Release lineage in `xmpp`
- First tag containing this commit: `1.2.6`
- Tags containing it include: `1.2.6`, `1.2.7`, `1.2.8`, and later.

## Likely First `ejabberd` Release Including Enforcement
Based on `ejabberd` tag -> `xmpp` dependency tag in `rebar.config`:
- `ejabberd 18.09` -> `xmpp 1.2.5` (before enforcement)
- `ejabberd 18.12` -> `xmpp 1.2.7` (after enforcement)
- `ejabberd 18.12.1` -> `xmpp 1.2.8` (after enforcement)

Likely first `ejabberd` release with this enforcement: **`18.12`**.

## Test Evidence in `ejabberd`
`ejabberd` suite contains explicit bad-lang stream test:
- `test_connect_bad_lang` expects `#stream_error{reason = 'invalid-xml'}` then stream end.
- File: [`ejabberd/test/ejabberd_SUITE.erl`](https://github.com/processone/ejabberd/blob/master/test/ejabberd_SUITE.erl)

## Practical Compatibility Guidance for Alternate Implementations
To emulate this behavior closely:
1. Validate `xml:lang` only on known fields/elements (codec-defined), not universally on every attribute.
2. If stream-start `xml:lang` is invalid, send stream `invalid-xml` and close stream.
3. If stream-start `xml:lang` length > 35 (client stream), send stream `policy-violation` and close stream.
4. If stanza-level/child validated `xml:lang` is invalid, return stanza/protocol error without dropping the connection.
