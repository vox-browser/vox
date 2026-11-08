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
