# Source isomorphic Blob response header encoding

Reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Feature commit: `242a95de`, following the separately committed
[actual Blob Request/Environment caller](BLOB_URL_FETCH_ACTUAL_REQUEST.md).

Source `Fetch/Fetching/Fetching.cpp:1103–1107,1169–1173` creates Content-Type
with HTTP::Header::isomorphic_encode in both full and ranged Blob responses.
`LibHTTP/Header.cpp:24–32` sends names and StringView/Utf16View values through
TextCodec. `LibTextCodec/Encoder.cpp:221–258` iterates code points, casts each
to one byte and logs values above U+00FF. Its range VERIFY is commented out.
`AK/Utf16View.h:39–79,111–116` combines valid surrogate pairs and advances lone
surrogates by one unit; replacing them before encoding would change output.

The new Encoding helpers follow those Source UTF8/UTF16 boundaries. The UTF8
arm uses the existing Source Utf8View conversion, preserving its overlong,
lonely-surrogate and invalid-sequence behavior, then the same code-point
encoding. Both HTTP Header overloads consume the result as raw byte strings.
The actual Blob scheme caller supplies its reconstructed UTF16 type to that
helper in both response arms. A retained snapshot still supplies type/data
after live Blob mutation and URL revocation. The standalone Legacy branch
keeps its previous byte-string response boundary.

The prior caller's type test observed WTF8 response bytes. That demonstrated
unvalidated type reconstruction but was not Source header-encoding proof.
This commit corrects that expectation: the pinned Source truncates the lone
U+D800 code point to byte 00, with its existing diagnostic, instead of exposing
ED A0 80. A valid pair U+1F680 likewise becomes one byte 80. This preserves
the pinned implementation, including its explicitly commented-out range
check; it does not add replacement characters or reject the internal type.

## Focused verification

The original real Page/Document/settings/Request test used type Aéÿ and
executed a precise failure: actual bytes `41 C3 A9 C3 BF`, expected Source
bytes `41 E9 FF`. Its probe, baseline commit and log hashes are retained.

The new primitive cases cover Latin-1 and empty input, valid pairs and lone
surrogates before truncation, and the unvalidated StringView boundary
(overlong slash, lonely surrogate and invalid FF). The HTTP case checks both
overloads, name encoding and raw bytes through the actual HeaderList. Actual
Blob owner tests check full and ranged responses, copied type/data after
mutation/revocation, and Content-Range. The corrected existing actual Fetch
owner test plus existing Legacy runtime tests pass with the same implementation.

| Run | Result | Seconds |
| --- | --- | ---: |
| Original actual header owner, GC-none | Executed UTF8/isomorphic-byte mismatch | 137.382 |
| Encoder/Header/actual owner, default GC | 3/3 PASS | 129.881 |
| Same files plus actual Fetch/Legacy runtime, GC-none | 5/5 PASS | 174.439 |

Default files: `encoding/isomorphic_encoder_test.v`,
`http/header_isomorphic_encoding_test.v`,
`html/blob_url_header_encoding_owner_test.v`. GC-none adds
`html/blob_url_fetch_owner_test.v` and `fetch/runtime_test.v`.
Commands use `VJOBS=2 v -old-compiler -enable-globals test`, adding `-gc none`
for that row. All seven implementation/test file hashes matched their saved
feature record before committing. Logs use `source-blob-header-` under
`Build/audit-fixes/`; exact argv, Source pin, original probe, feature and log
hashes and summaries are in `source-blob-header-manifest.json`, SHA256
`1379ed9790bc04a3a3e8c28f68429ac732849bc3d8014183bc66353716b6413f`.

This completes the bounded Source encoder/header/Blob type boundary. These
are focused checks, not a full Encoding/HTTP/Fetch sweep. Other response and
binding conversions, native public URL exposure, remote IPC, OOM/allocation
and complete GC ownership remain separate. The earlier caller phase's main
regression predates this header feature; no new production or screenshot proof
is claimed. The ledger remains **32 fixed / 25 partial / 9 open**.
