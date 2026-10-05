# Native URL Blob/File object-URL methods and actual page caller

Source pin: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Feature commit: `4e83907a`, with implementation and both focused test files
committed together.

Source DOMURL.idl declares createObjectURL(Blob or MediaSource) and
revokeObjectURL(DOMString). This slice exposes the Blob/File branch and
revocation on the native URL constructor. At this feature commit the MediaSource native wrapper and
union branch were pending; no ID-only or tagged substitute was accepted.
The [subsequent native MediaSource slice](NATIVE_MEDIA_SOURCE_OBJECT_OWNER.md)
now implements that live-object arm with separate verification.
The browser continues to execute JavaScript through JavaScriptCore.

Generated argument-count checks precede conversion. Blob lookup uses actual
native wrapper identity, including File's embedded Blob base. Prototype and
Symbol.toStringTag spoofing, Proxy wrappers and author Symbol.hasInstance do
not change that brand or trigger author getters. Invalid union values retain
the pinned generated "No union types matched" TypeError message. Methods have
native engine metadata and Source static-operation property flags; static
receiver values do not require URL branding.

Creation and revocation call the actual HTML current-settings operations,
which obtain their owner from the execution-context stack. The typed FileAPI
store retains the genuine Blob and settings object. Creation after Window
reassociation reads that settings owner's current Document origin. Document
unload removes entries by settings identity, while another Document starting
at the same URL/origin retains its entries. Parsed snapshots keep prior origin,
bytes and type after reassociation, mutation and revocation.

Revocation converts an engine value to DOMString while preserving raw UTF-16
code units, unlike the URL core's USVString conversion. Coercion uses the
string hint, propagates thrown engine values by identity and rejects Symbols.
The translated parser still has its separately documented UTF-16/string
boundary. Invalid, non-blob-scheme and missing URLs are silent; provided undefined
is converted rather than treated as a missing argument. Real opaque origins
that both serialize to null remain distinct partitions; another actual owner
with the same opaque identity can revoke. Source's retained fragment-removal
behavior is checked explicitly.

A page fixture creates real Blob and File records through normal browser
navigation and script startup. It verifies document text replay/load order,
store object/settings identity, native File-to-Blob identity, and a Request
parsed before revocation reaching the actual Blob Fetch response afterward.
The network callback is not used. Separate host cases verify live data changes
produce fresh snapshots while existing requests retain their bytes/type.
HTML and VM contexts return to idle after the author calls.

| Run | Result | Seconds |
| --- | --- | ---: |
| Original native global | Executed createObjectURL absence assertion fails | 165.689 |
| Reserved-keyword fixture run | Stopped after compiler failure; no complete batch result | — |
| First complete default batch | Two passing neighbors; one compiler-only failure and one executed caller-fixture failure | 438.665 |
| Corrected native object-URL host, default GC | 1/1 file PASS | 179.367 |
| Corrected navigation page caller, default GC | 1/1 file PASS | 194.250 |
| Focused/neighbor batch, GC-none | 7/7 files PASS; two exact Source outputs | 350.743 |

The initial fixture used V's reserved `shared` keyword; its command was stopped
with exit 143 after the compiler diagnostic. The first completed batch then
caught accesses to HTML-private settings fields in the host fixture. Only
that fixture changed to Document's public relevant-settings boundary before
its passing retry. The original page fixture parsed an opaque about:blank
Document while supplying an HTTPS script-bridge URL label and incorrectly
expected a tuple origin. Its executed DOM text contained `blob: null`.
The corrected caller uses the actual browser navigation helper, which determines and owns
the Document's origin before parsing. The original opaque-origin behavior is
preserved. The initial host has zero test runtime; the page mismatch is an
executed assertion failure. All original diagnostics are retained.

Final default coverage spans four files across three commands: the two URL
core/Source-fixture neighbors in the mixed batch plus the two corrected
retries. Only the two new fixture files differ from the initial default
snapshot; implementation and neighbor test closures are unchanged. Both
unmodified Source URL fixture outputs match all 377 lines in this batch.
The GC-none batch uses `VJOBS=3` and adds the Blob constructor neighbor, actual
typed partition/revoke owner and existing 66-case main regression.

Exact argv/environment overrides, exit codes, log hashes, retained initial
fixtures, exact-output hashes and final feature hashes are recorded in
`Build/audit-fixes/source-url-object-blob-manifest.json`, SHA256
`5ad4ffddc775df9979331a73895dc2fa11188cac3c79631101478d0e425346df`.
The final code snapshot has SHA256
`2c63bc2b07961f5b40b0c57a2ec91abd6206b5379c6f4da9e0aa97792f5bd74e`.
It was captured during the corrected page-caller compilation, after the host
retry and before GC-none. All **3,170 recorded V/native-helper files**,
**34 selected Source references** and both compiler executables remain
unchanged through that page retry and the final seven-file GC-none command.
The manifest also retains the earlier snapshot and its two test-only changes;
it does not claim the earlier mixed run used the final whole-code snapshot.
External native libraries and the whole toolchain are outside this record.

The refreshed `4e83907a` inventory remains **432,266 implementation V LOC /
153,384 test V LOC** across 78 owners. Browser/root integration is excluded.
Artifact `Build/audit-fixes/source-current-module-loc-4e83907a.json` has SHA256
`af2f82659045167ef53acc3c0d4515a0c5325fcd121e2f838b2ed935669b068d`.
These physical counts and source-unit mappings do not establish parity.

This proof predates the native MediaSource branch. Foreign realm/world
wrappers, Worker startup,
complete parser encoding boundaries, generated diagnostic text beyond the
union message, allocation limits, physical GC edges and IPC remain separate.
The [previous frozen production bundle](FROZEN_F273F1EF_BLOB_URL_CONTINUATION.md)
predates these native methods; no updated production or screenshot verification is claimed.
The audit remains **32 fixed / 25 partial / 9 open**.
