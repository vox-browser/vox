# DOMURL constructor value ownership

Reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Feature commit: `c1e5845d`, with implementation and the two-case regression
committed together. It was reviewed privately against `f273f1ef` while that
canonical commit stayed frozen for production and package verification.

Source `DOMURL/DOMURL.cpp:23–26,49–53,85–89` passes a URL value into the new
platform object. `LibURL/URL.h:158–173,207` and `AK/CopyOnWrite.h:21–26` keep
later caller mutations independent through copy-on-write data. The translated
`DOMURL.create()` retained the caller's mutable V path array. It now copies
the typed URL record at that boundary, including its copied Blob entry.
`initialize_a_url()` and API constructors use that same boundary.

The original two-case test executes both alias failures: changing the supplied
record's first path changed `DOMURL.create()`'s href, and changing its second
path likewise changed `initialize_a_url()`'s href. Final tests also verify
component updates remain independent and the lazy query object keeps its
identity and contents.

| Run | Result | Seconds |
| --- | --- | ---: |
| First private probe | Missing upstream WOFF2 support path; no assertions executed | 97.838 |
| Probe with restored upstream path, GC-none | Both alias assertions fail | 88.654 |
| Private DOMURL module, default GC | 3/3 files PASS | 87.041 |
| Private module plus actual owner, GC-none | 3 PASS; owner compile needs private regex archive | 339.440 |
| Actual owner retry with archive restored, GC-none | 1/1 PASS | 129.584 |

The three module files are the new constructor regression, existing embedded
Blob entry owner, and URLSearchParams/URL tests. The additional actual owner
is `html/blob_url_dom_record_owner_test.v`. These results cover all four files
with GC disabled across two runs; they are not a clean four-file batch.
The private dependency paths resolve to the canonical upstream checkout and
repository-built regex archive; their setup diagnostics remain separate from
executed behavior failures.

All five implementation/test hashes stayed unchanged during final checks and
matched the canonical files after fast-forward integration. Exact argv,
original/final hashes, dependency paths/archive hash, individual outcomes and
all five log hashes are in
`Build/audit-fixes/source-domurl-constructor-copy-manifest.json`, SHA256
`4bc405f615c9d4f0144718bc1bed262de5f01f4e063201111c3476a195b52caf`.

The [frozen browser verification](FROZEN_F273F1EF_BLOB_URL_CONTINUATION.md)
predates this constructor fix. This slice verifies typed value ownership;
native public URL WebIDL exposure, UTF16/encoding-aware parsing, allocation,
remote IPC and full GC/WrapperWorld ownership remain open. The audit ledger
remains **32 fixed / 25 partial / 9 open**.
