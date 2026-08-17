# SRI translation status

Complete, independently audited translation of `Libraries/LibWeb/SRI`.

| Upstream `.cpp` | V implementation |
| --- | --- |
| `SRI.cpp` | `sri.v` |

Metadata parsing, strongest-hash selection, SHA-256/384/512 application and
case-sensitive integrity matching are translated directly. V's standard
SHA-2 and base64 implementations replace LibCrypto and AK.

- Upstream: 1 `.cpp` file, 191 LOC; its adjacent header audited.
- V implementation: 147 LOC in 1 file.
- V tests: 95 LOC in 1 file (9 test functions).
- Verification: `v test sri` and `v fmt -verify sri`.
