# First 100 newly imported Ladybird tests

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
pass. The required Volt build and `make app` both pass. One development compile
was blocked by a concurrently edited CSS file; a later clean compile passes.
The first combined binding run also exposed a test-fixture lexical redeclaration,
which was corrected before the final three-case binding check passed. Those
failed attempts and the successful checks remain in the manifest and local
focused archive. The source fixes are committed as `99e7bece5` and `c61d61c2e`;
the batch selector is `1afc80e15`.

Production validation of these fixes remains pending. The existing shared build
was busy and its sealed inputs predated
these changes; no duplicate production build was queued.

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
