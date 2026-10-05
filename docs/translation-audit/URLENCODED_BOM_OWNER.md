# URL-encoded tuple BOM preservation

Source pin: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Feature commit: `554c7759`, including implementation and both focused cases.

`DOMURL/URLSearchParams.cpp::url_decode()` constructs names and values with
`Utf16String::from_utf8_with_replacement_character(..., WithBOMHandling::No)`.
Leading U+FEFF therefore belongs to each tuple. The translated caller used
the default TextDecoder, which consumes a leading UTF-8 BOM. It now selects
UTF-8 with `ignore_bom: true`, using the existing genuine decoder owner and
its replacement handling. Decoder allocation failure is fatal; the change
does not alter the module's existing allocation boundaries.

The original two-case file executes both failures: a decoded name/value loses
its leading BOM, and a DOMURL's actual lazy query object cannot find its
BOM-prefixed name. Final assertions check malformed and truncated UTF-8,
serialization, query mutation, replacement and same-object query identity.

| Run | Result | Seconds |
| --- | --- | ---: |
| Original caller | Both focused cases fail | 28.947 |
| Complete DOMURL module, default GC | 4/4 files PASS | 29.235 |
| First GC-none command | Invalid neighboring test filename; no tests execute | — |
| Complete module plus Common UTF-8 decoder owner, GC-none | 5/5 files PASS | 35.694 |

Exact argv, final implementation/test hashes, original diagnostics and log
hashes are retained in `Build/audit-fixes/source-urlencoded-bom-manifest.json`,
SHA256 `ee7bc8a07edd3590b1c156088d53a9a15d180acd0ff5bd973a330cedd88280e7`.
These are focused module/neighbor checks. They postdate the
[frozen native bundle](FROZEN_F273F1EF_BLOB_URL_CONTINUATION.md).
Native public URL bindings, foreign realms, allocation and full wrapper GC
remain separate. The audit remains **32 fixed / 25 partial / 9 open**.
