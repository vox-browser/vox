# Literal question marks in lazy query owners

Source pin: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Feature commit: `4bdb79ab`, including the implementation and two focused cases.

Source `DOMURL.cpp::search_params()` initializes from the URL record's query
using `URLSearchParams::create()`. That overload parses the query directly.
Only the public URLSearchParams string constructor removes a leading `?`.
The V lazy getter previously used that constructor, so a URL ending in
`??name=value` incorrectly exposed `name` instead of `?name`.
It now parses the stored query directly and binds the resulting actual list
to the same DOMURL owner.

The original focused file executes a missing-name failure in its first case;
its panic stops the process before the second case. Final tests verify lazy
and previously observed query objects agree after href/search replacement,
query serialization preserves the literal character, same-object identity
survives, and the public string constructor still strips its delimiter.

| Run | Result | Seconds |
| --- | --- | ---: |
| Original lazy getter | Missing literal name causes an executed panic | 30.474 |
| Complete DOMURL module, default GC | 5/5 files PASS | 34.878 |
| Complete module plus native query binding, GC-none | 6/6 files PASS | 211.647 |

Exact argv, final implementation/test hashes and log hashes are recorded in
`Build/audit-fixes/source-query-leading-question-manifest.json`, SHA256
`9ddd71bf519462ef31fe723da811aa7b50cf916cc248c07bff9d7726ff4c2453`.
These focused checks precede the next native URL binding slice and postdate
the [previous frozen browser bundle](FROZEN_F273F1EF_BLOB_URL_CONTINUATION.md).
The audit remains **32 fixed / 25 partial / 9 open**.
