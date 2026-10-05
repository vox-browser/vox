# Encoding translation status

Typed translation of `Libraries/LibWeb/Encoding`, with internal LibTextCodec
helpers used by Blob and FileReader. This inventory does not establish complete
Source runtime, generated native bindings or legacy decoder parity.

| Upstream `.cpp` | V implementation |
| --- | --- |
| `TextDecoder.cpp` | `text_decoder.v` |
| `TextEncoder.cpp` | `text_encoder.v` |
| `TextEncoderCommon.cpp` | `text_encoder.v` |
| `TextEncoderStream.cpp` | `text_encoder_stream.v` |
| `LibTextCodec/Decoder.cpp` given-decoder BOM helper | `decode_with_bom_override.v` |
| pinned `encoding_rs` 0.8.40 replacement decoder | `replacement_decoder.v` |

The implementation also covers the label and BOM helpers used by the four
translation units. The V boundary uses `iconv` for legacy encodings not
provided by V's standard library; UTF-8, UTF-16 and `x-user-defined` retain
typed streaming, fatal-error, BOM and surrogate state locally.

The original 4-source/438-LOC, 668-V-LOC and 26-test-function counts are a
historical inventory, not a current completeness measurement. Legacy encodings
still use iconv and its compatibility error fallback; that boundary does not
reproduce Source's full Rust decoder state and malformed-input behavior.

The internal replacement decoder now translates the Source dependency's actual
emitted/capacity/malformed state and replacement wrapper. The given-decoder
helper routes replacement after Unicode BOM selection; public TextDecoder
continues to reject it. Focused raw decoder, internal helper, public decoder
stream and FileReader packaging tests pass **5/5 in both GC modes**. Native
probes compile the actual pinned Rust bridge and dependency and pass **2/2 in
debug and release**. Source mapping, exact dependency checksum and remaining
FileReader owner boundaries are recorded in
[`FILEREADER_TEXT_SOURCE.md`](../docs/translation-audit/FILEREADER_TEXT_SOURCE.md).

Pinned LibTextCodec isomorphic UTF8/UTF16 encoding (`242a95de`) now uses
Source code-point iteration and byte truncation, retaining its diagnostic
above U+00FF and its commented-out range VERIFY. The HTTP Header overloads
and genuine Blob scheme caller consume those bytes. [Source header evidence](../docs/translation-audit/BLOB_URL_HEADER_ISOMORPHIC_ENCODING.md)
records the executed original byte mismatch, pairs/lone surrogates and
**3/3 default / 5/5 GC-none** focused caller/neighbor files. Physical
allocation, OOM and other encoder/binding boundaries remain separate.
