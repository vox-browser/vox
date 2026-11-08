# First 100 newly imported Ladybird tests

The target workspace is `/Users/alex/code/vox2`. Earlier Volt build checks
were incidental to the initial workspace setting; they neither validate Vox
nor block this work. Validation follows this repository's Vox instructions.

The first batch is pinned to Ladybird `2919bf87a5e5dfc49a210a70bda079afa411c6c5`,
the latest fetched `origin/master` on 2026-11-08. The upstream working checkout
remains at `963d46a829f3e1b79f44dba9d02afb70654300fa`.

Selection uses the existing imported WPT expectation discovery order, removes
IDs present at that older revision, and takes the first 100 remaining IDs.
Worker and query variants remain separate cases. There are 3,063 new runnable
IDs among 6,828 current imported cases, versus 3,808 at the baseline. Changed
existing IDs are outside this batch. The immutable fixture exports include the
supporting resources; neither upstream checkout nor WPT assertions are edited.

**The batch fails.** The available production executable, SHA-256
`b8c5285a19472a2abaddcbe8c3bafcc232aeea611a151ee6b0b6b7f33dc6553a`,
fully passes 26 of 100 cases and 6,927 of 8,418 reported subtests. It reports
1,470 FAIL, 5 TIMEOUT and 16 NOTRUN subtests. All 100 documents report;
83 harnesses are OK, 16 TIMEOUT, and one ERROR. There are no crashes or
browser-memory-limit stops. These counts predate this session's source fixes.

| Group | Selected cases | Fully passing |
|---|---:|---:|
| FileAPI | 5 | 0 |
| IndexedDB | 42 | 3 |
| WebCryptoAPI | 46 | 23 |
| Clipboard | 1 | 0 |
| Compression | 1 | 0 |
| Content Security Policy | 5 | 0 |

The [batch manifest](performance/ladybird-new-first100-20261108.json) retains
every selected ID, source and expectation hashes, case results, failure examples,
executable and library hashes, production receipt, commands, guard exit, and a
hash of the local raw-evidence archive. All input identities remain unchanged.
The strict `--require-all-pass` runner and its guard both exit 1. The 3 GiB
aggregate guard observes 1,131,134,976 bytes peak RSS; each browser has a
2 GiB cap. Five fresh processes use private profiles, chunks of 20, and the
existing harness deadlines at a 1024 by 768 viewport.

The static HTTP runner lacks WPT Python handlers, HTTPS, and full multi-origin
configuration. The form-upload tests need an upstream Python response handler.
Other failures include worker IndexedDB exposure, cursor/index operations,
transaction events, WebCrypto numeric conversion and newer operations, clipboard,
compression, and CSP worker enforcement. Some imported expectations themselves
contain failing assertions; the strict acceptance check still requires every
assertion to pass. This result is neither full upstream WPT conformance nor a
timing comparison. A concurrent broader sweep and production compilation were
active during this focused run.

Source changes from this batch correct UTF-8-only `Blob.text()` decoding and
expose committed database snapshots through `indexedDB.databases()`. Focused
verification passes all nine distinct model, promise, worker-realm, and native
binding test functions with default allocation. All 19 WPT tooling unit tests
pass. Incidental Volt builds also passed. One development compile
was blocked by a concurrently edited CSS file; a later clean compile passes.
The first combined binding run also exposed a test-fixture lexical redeclaration,
which was corrected before the final three-case binding check passed. Those
failed attempts and the successful checks remain in the manifest and local
focused archive. The source fixes are committed as `99e7bece5` and `c61d61c2e`;
the batch selector is `1afc80e15`.

Production validation of these fixes remains pending. The existing shared build
was busy and its sealed inputs predated
these changes; no duplicate production build was queued.

## WebCrypto continuation

Four further fixes are committed:

| Fix | Commit |
|---|---|
| Enforce numeric parameter ranges instead of wrapping oversized values | `30e94987a` |
| Normalize public key usages to a sorted set without duplicates | `038d76f72` |
| Copy imported bytes after algorithm normalization, preserving getter mutations and detachment | `3f738c55e` |
| Accept ML-DSA signing JWKs with `use: "sig"` and reject unrelated uses | `5bae25dd4` |

**All 4,304 subtests in the 16 affected upstream files pass through Vox's
native JavaScriptCore bindings.** Seven generation-failure files account for
3,066 subtests; nine generation/import files account for 1,238. Their case IDs
and complete multisets of subtest names match the saved browser baseline,
which passed 3,716 of those same names. There are 588 previously failing names
now passing in this source check. All pinned upstream script bytes and
assertions remain unchanged.

These are non-windowed checks using the stock harness's shell environment,
real Vox Crypto/Base64/URL bindings, and explicit native task and microtask
delivery. The URL has no query, so the subset helper runs every subtest.
They do not exercise the HTML parser, navigation, rendering, or workers and
do not replace the published browser's 26/100 baseline. No new browser-wide
pass rate is claimed. The shared production/publication guard remains busy;
the latest published executable is still `b8c5285a1947…`.

The final focused checks also pass ten numeric-model tests, five native
generation tests (including 35 range rejections before backend work), three
native cipher tests, 23 usage/model regressions, five native import tests,
and three ML-DSA model/vector tests. Checks use default allocation and bounded
runtime guards; production allocation remains unverified for these changes.
Development failures and their corrections are retained in the
[continuation manifest](performance/ladybird-first100-crypto-20261108.json)
and its local raw archive.

The incidental Volt `make app` check passed. Its plain `v -enable-globals -o volt .` build failed
in the shared compiler's cached C prefix with an incomplete `macos_range` and
conflicting macOS function declarations. Its compatibility fallback then rejects
the current global declaration in `forms/window.v:69`. These historical Volt
outcomes are unrelated to Vox acceptance and do not block the remaining work.

## IndexedDB keyPath continuation

Commit `5dbbec6fc` retains each object store's and index's JavaScript `keyPath`
array for the lifetime of its wrapper. Repeated reads return the same object;
different transactions retain separate arrays. Author mutations remain visible
through that wrapper while the native database schema stays unchanged.

All ten focused IndexedDB regression functions pass. The unchanged upstream
`IndexedDB/idbobjectstore_keyPath.any` test now passes its single subtest through
Vox's native bindings; that same subtest failed in the original browser baseline.
This uses the stock shell harness and default allocation. Windowed browser
validation remains pending because the published executable predates the fix
and the shared build guard is busy. The
[keyPath manifest](performance/ladybird-first100-key-path-20261108.json)
records source hashes, results, bounded-check receipts, and the local evidence
archive. The full first-100 result remains pending.

## IndexedDB cursor continuation

Commit `723954c1a` exposes native object-store and index cursors, including key-only
cursors, `continue()`, `advance()`, and `continuePrimaryKey()`. Iterations reuse
their request through the transaction's ordered queue. JavaScript key and value
objects keep their identity during an iteration and refresh for the next result.
Index lookup retains the same wrapper across renames and distinguishes recreated
indexes. Source and transaction errors precede author key conversion.

All 13 binding checks and all 59 IndexedDB model test functions pass. The final
six-file upstream source check passes **32 of 33 subtests**, with unchanged script
hashes and exact subtest-name multisets matching the original browser baseline:

| Case | Passing subtests |
|---|---:|
| `idbcursor-key.any` | 3/3 |
| `idbcursor-primarykey.any` | 3/3 |
| `idbindex_keyPath.any` | 3/3 |
| `idbobjectstore_keyPath.any` | 1/1 |
| `keypath.any` | 19/20 |
| `keypath_maxsize.any` | 3/3 |

The original baseline passed none of those 33 names. One passing name already
belongs to the preceding keyPath fix, leaving 31 additional passing names in
this continuation. The remaining test expects a `RangeError` for conversion of a
self-referential array; JavaScriptCore accepts that conversion. Its assertion
remains unchanged and failing.

These checks use native bindings with the stock shell harness and default
allocation. They provide no windowed or worker acceptance credit. The shared
production build guard remains busy and the published executable still predates
the fixes. The full first-100 batch is not green. The
[cursor manifest](performance/ladybird-first100-cursors-20261108.json)
retains all results, input hashes, bounded-check receipts, development failures,
and the local evidence archive identity.

## Public-key derivation and Blob source checks

Commit `eec0bbbba` adds `crypto.subtle.getPublicKey()` for all 15 currently
supported asymmetric algorithm names. It derives public material from the native
private-key handle, including non-extractable keys and EC keys without a retained
public point. Returned keys are distinct, extractable public keys with normalized
usages. Capability errors reject immediately; key-type, usage and derivation
results settle through the crypto task source.

All 11 model and 15 native binding test functions pass. The unchanged upstream
`WebCryptoAPI/modern-algos/getPublicKey.https.any` file passes **37/43 subtests**,
versus zero in the original baseline. Its six remaining failures occur during
`generateKey()` for `MLKEM768-P256`, `MLKEM768-X25519`, and `MLKEM1024-P384`, each
with ordinary and empty public-key usages. Those hybrid algorithms remain
unsupported; the full upstream file is still failing.

The same continuation verifies the earlier Blob implementations against both
unchanged upstream files: `Blob-text.any` passes **16/16**, and
`Blob-textStream.any` passes **8/8**. The original baseline passed 13 and zero,
respectively. These checks validate commits `99e7bece5` and `f3c82806a`; no Blob
implementation changes were needed here.

Every case and subtest-name multiset matches the original cohort. Assertions
and upstream script bytes remain unchanged. The source checks use the stock
shell harness, native bindings and default allocation, with no windowed or
worker acceptance credit. The full first-100 batch remains unfinished, and
production validation still needs a newer completed browser bundle.

The first binding selection failed two fixture expectations. The new usage
conversion fixture now follows the pinned WebIDL generator's behavior without
IteratorClose on conversion failure. Commit `f4f3c1438` corrects an existing
AES generation expectation to the upstream KeyUsage enum order. The successful
26-function rerun, all upstream results, source hashes, guard receipts and local
archive identity are retained in the
[public-key manifest](performance/ladybird-first100-public-key-20261108.json).

## Algorithm support, hybrid KEMs and ML-KEM JWKs

The six affected modern-crypto upstream files now pass **972/972 subtests**
through the native JavaScriptCore shell harness, compared with 297 passing
names in the original baseline. This supersedes the earlier 37/43 public-key
result: `getPublicKey` now passes 43/43. Both support-query files pass 347/347,
the encapsulation files pass 258/258, and ML-KEM import/export passes 324/324.
Every case and subtest-name multiset matches the original cohort.

The source adds parameter-aware `SubtleCrypto.supports()`, three hybrid KEMs
with upstream fixed-vector verification, and ML-KEM public/private JWK import
and export with metadata and public/private consistency validation. The
[modern-crypto manifest](performance/ladybird-first100-modern-crypto-20261108.json)
records commits, focused checks, unchanged upstream inputs, guard receipts,
development failures and the local raw archive. These remain source checks;
the older published browser cannot validate these changes, and the entire
100-case batch is still incomplete.

## IndexedDB worker, request-order and clone continuation

All **138/138 subtests in 18 affected upstream files now pass** through native
bindings: 105 subtests across all 14 dedicated-worker cases, plus 33 subtests
in four files checked with actual Window settings and the stock shell harness.
All case IDs and complete subtest-name multisets match the newer browser refresh
for the same immutable cohort. The previously failing recursive key-path test
now passes 20/20 through source-compatible string conversion; global JavaScript
built-ins remain unchanged.

The fixes cover event capture/bubbling, queued abort notifications, ordered index
population and reads, numeric count results, rollback metadata, closed connection
name snapshots, raw UTF-16 names, invalid inline keys, cursor updates, and native
Blob/File cloning. All 74 model functions across 23 files pass. A 22-function
native regression run passes, as does the seven-function index/conversion file.

These API checks use real dedicated worker globals or Window settings; they do
not replace production navigation, worker-process transport or renderer checks.
FastC probe builds compile but fail several native checks or crash; the accepted
checks use the C backend. The shared production build remains busy. The
[IndexedDB follow-up manifest](performance/ladybird-first100-idb-followup-20261108.json)
retains successful checks, development failures, source/fixture identities and
the local raw archive. Shared-worker exposure and the remaining non-IndexedDB
failures still need work, and no new complete-browser pass rate is claimed.

## Published-browser refresh

A newer completed shared browser, SHA-256
`3feee902668f98c768c03d9f745870d900d52d687cb11fff37dd47f73b8b7c5c`,
now fully passes **62/100 cases**, up from 26/100. It passes 8,183 of 8,462
reported subtests, with 256 FAIL, eight TIMEOUT and 15 NOTRUN. The strict
all-pass check still exits 1. All original 100 case IDs are retained, all
documents report, and executable and fixture identities stay unchanged
throughout five fresh browser processes.

This executable predates the ML-KEM JWK and subsequent IndexedDB source
fixes. It validates the earlier crypto, Blob, cursor and dedicated-worker
exposure changes, including all 28 crypto IDL subtests. Shared-worker cases
still time out. The static server still lacks Python handlers, HTTPS and
complete multi-origin support. The
[browser refresh manifest](performance/ladybird-first100-browser-refresh-20261108.json)
records the remaining failures and the local raw archive. The task remains
open until the complete new cohort passes.

Reproduce the exact selection from the canonical Vox checkout:

```sh
python3 tools/run_memory_bounded.py --limit-gib 3 \
  --lock Build/ladybird-first100-repeat.lock \
  --report Build/ladybird-first100-repeat-guard.json -- \
  python3 tools/wpt_compare.py --output Build/ladybird-first100-repeat \
    --ladybird-ref 2919bf87a5e5dfc49a210a70bda079afa411c6c5 \
    --new-since 963d46a829f3e1b79f44dba9d02afb70654300fa \
    --limit 100 --browsers vox --chunk-size 20 \
    --browser-memory-gib 2 --require-all-pass
```

## Upstream server and compression continuation

The next published browser, SHA-256
`c7079cad06a2637240b8eab7e3ab6836e4c086a4fc714c706f7494ed3fe516d0`,
passes **77/100** cases in a fresh windowed run of the same pinned cohort.
It reports 8,375 PASS, 8 FAIL, 4 TIMEOUT and 15 NOTRUN subtests. The first
upstream-server configuration omitted WebSocket placeholders used by a shared
security helper, so five CSP cases reached the outer timeout without reports.
After correcting the configuration, those exact five cases all report with
harness OK; all five still contain failing assertions. The 100-case batch
remains incomplete. The executable predates several final IndexedDB fixes.

The runner now optionally uses an existing upstream WPT checkout with
`--wpt-server-root`. Python upload handlers, stash, response headers,
substitution, localhost aliases and two HTTP/HTTPS ports use real wptserve.
All 22 tooling tests pass, including binary upload/stash and a TLS client
trusting the isolated test CA. WebSocket listeners remain unavailable and are
recorded explicitly; the browser run uses HTTP. See the
[server/browser report](performance/ladybird-first100-upstream-server-20261108.json).

Commit `15a9f7020` replaces the JavaScript decompression buffer with an owned
incremental zlib/Brotli context behind native TransformStream queues. Decoded
bytes reach a pending reader before trailing input errors the stream, without
requiring writable close. It accepts the current `brotli` IDL spelling,
validates BufferSource internal slots, and closes codec state on cancellation,
errors and runtime shutdown. All four unchanged upstream extra-input subtests
pass, with names matching the saved browser run. Twelve model functions and
three native binding functions pass, including the optional upstream harness.
The [compression report](performance/ladybird-first100-compression-20261108.json)
retains successful and failed development attempts. This source check does not
replace production browser validation. Raw evidence is archived locally and
all completed job scratch has been removed.

## Native SharedWorker continuation

Commit `d67ae676b` adds native SharedWorker globals, independent worker agents,
queued connect events and reusable connections backed by actual MessagePorts.
The parent registry reuses the agent for same-origin URL/name keys across
Window owners. Port identifiers remain distinct between connections; closing
one Window preserves another owner's connection, and the final owner closes
the agent. Native JavaScriptCore globals carry the correct SharedWorker class.
Connect events retain their empty-string data and port source identity.

All **52 subtests in the ten selected IndexedDB SharedWorker variants pass**
through fresh native worker processes and unchanged upstream worker wrappers,
support scripts and assertions. The upstream parent shell harness collects
results over real process/port transport. All 23 dedicated/shared worker
regression functions pass, and the independent two-window reuse and constructor
checks pass. This does not replace production windowed browser validation.
`extendedLifetime` conversion does not implement a post-owner grace lifetime,
and the registry does not claim cross-browser persistence. See the
[SharedWorker report](performance/ladybird-first100-shared-workers-20261108.json)
for identities, per-case results, failed development checks and local evidence.


## Production refresh and form/CSP source checks

The next completed production executable, SHA-256
`59de419d75f2cacafe67899969e35f8c0fe4c1c935e7720eb50921ab5a3bf357`,
passes **82/100 cases and 8396/8462 subtests** in the unchanged cohort using
upstream wptserve. There are 87 harness-OK cases and 13 harness timeouts.
The remaining 18 cases are ten SharedWorker variants, three multipart upload
pages and five CSP pages. This bundle includes incremental decompression and
passes all four corresponding upstream subtests. It predates the subsequent
SharedWorker, form and CSP fixes.

Source commits `c238849e7`, `a5e36790d` and `d30bfc72f` add legacy form submit
navigation, creator-window worker CSP enforcement, and HTML form charset
encoding. Focused checks pass two form binding/navigation functions, two native
worker-CSP functions, two CSP owner/destination model functions, three encoder
functions (including all three pinned upload encoding vectors), two multipart
functions and three existing UTF-8 serializer functions. These focused results
are separate from full upstream upload integration, which remains under repair.
The [manifest](performance/ladybird-first100-forms-csp-browser82-20261108.json)
retains the production results, guard exits and local archive identity.
