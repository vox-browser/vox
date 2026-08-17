# Encoding translation status

Complete, independently audited translation of `Libraries/LibWeb/Encoding`.

| Upstream `.cpp` | V implementation |
| --- | --- |
| `TextDecoder.cpp` | `text_decoder.v` |
| `TextEncoder.cpp` | `text_encoder.v` |
| `TextEncoderCommon.cpp` | `text_encoder.v` |
| `TextEncoderStream.cpp` | `text_encoder_stream.v` |

The implementation also covers the label and BOM helpers used by the four
translation units. The V boundary uses `iconv` for legacy encodings not
provided by V's standard library; UTF-8, UTF-16 and `x-user-defined` retain
typed streaming, fatal-error, BOM and surrogate state locally.

- Upstream: 4 `.cpp` files, 438 LOC; all 4 adjacent headers and 4 IDLs audited.
- V implementation: 668 LOC in 5 files.
- V tests: 235 LOC in 4 files (26 test functions).
- Verification: `v test encoding` and `v fmt -verify encoding`.
