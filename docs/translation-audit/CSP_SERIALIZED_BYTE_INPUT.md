# Serialized CSP byte-sequence decoding

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/ContentSecurityPolicy/Policy.cpp:23–89` and
`Libraries/LibTextCodec/Decoder.cpp:584–596`.

Source's serialized CSP parser distinguishes String input from ByteString
input. It isomorphically decodes a byte sequence first: each byte becomes the
Unicode code point with the same numeric value. The result then follows the
same directive parser as String input and is retained as the policy's original
text for reporting. UTF-8 decoding and the web Encoding label `ISO-8859-1`
(which selects Windows-1252) do not implement that Source step.

The existing V parser only exposed its String path. The new explicit byte
entry point translates Source's ByteString branch by mapping byte values to
code points before invoking that existing parser. Both module and Policy
entry forms delegate to the same body. The separate ASCII-token prerequisite
preserves Source's complete ASCII range and five-whitespace parsing rules.
No header splitting or policy owner is introduced here.

Three focused cases in `contentsecuritypolicy/serialized_csp_byte_input_test.v`
check exact original-text metadata for high bytes, including C1 controls,
nonbreaking space and invalid UTF-8 bytes; distinguish String input from the
same String's UTF-8 byte sequence; and retain ASCII whitespace, first duplicate,
source/disposition and cloned metadata behavior.

For the absent pre-fix byte entry point, a temporary identity delegation to
the existing String parser supplied a bounded comparison. That delegation was
not an existing translated byte method. Its two decoding cases failed in
12.24 seconds (`Build/audit-fixes/source-csp-byte-input-original-default.log`),
and its ASCII control also exposed the independently fixed token bug. With
decoding corrected but token handling still unchanged, a two-file run had the
existing parser file pass and new byte file fail its ASCII control
(`source-csp-byte-input-default.log`, 14.36 seconds). Both diagnostic outcomes
are retained separately from the final validation. With the independently
committed token prerequisite, the corrected default two-file batch passed in
15.92 seconds (`source-csp-byte-input-corrected-default.log`), covering the byte
entry and existing directive/parser file. The GC-none three-file batch passed
in 19.24 seconds (`source-csp-byte-input-gc-none.log`), covering the new byte
entry, separately completed ASCII token rules and existing directive/parser
neighbors. Earlier failures and the partial run remain separate diagnostics.

Actual CSP response HeaderList extraction and HTML's Fetch-response factory
remain later caller translations. This byte-input branch does not claim full
native Policy/GC ownership or the complete LibTextCodec module.
