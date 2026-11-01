# Cached Old Reddit programming instructions, 2026-11-01

Across seven alternating fresh-process pairs, Vox's median is **4,954,400,539
observed retired CPU instructions** versus Brave's **9,248,675,091**: **46.43%
fewer** by the ratio of medians. The highest observed Vox count is **45.91%
below the lowest observed Brave count**, passing the requested 10% gate.
All 14 document captures match the same fixed Brave reference at all **786,432
pixels**, and every trial preserves all **25 post IDs in source order**.

This measures a **cached, frozen `https://old.reddit.com/r/programming/` page**,
with executable scripts removed and normal JavaScript policy retained for
`noscript` semantics. It does not measure the live site. Direct and proxied
requests return HTTP 403, and isolated Brave also displays `Blocked`. Those
acquisition attempts receive no instruction credit. The new fixture differs
from the [historical home-page result](OLD_REDDIT_INSTRUCTIONS.md); the old
private fixture and receipts remain unavailable.

| Pair | Vox observed instructions | Brave observed instructions | Differing pixels, Vox / Brave |
| --- | ---: | ---: | ---: |
| 1 | 4,979,489,773 | 9,320,609,714 | 0 / 0 |
| 2 | 4,980,456,229 | 9,248,675,091 | 0 / 0 |
| 3 | 4,954,400,539 | 9,350,859,863 | 0 / 0 |
| 4 | 4,934,338,475 | 9,218,135,900 | 0 / 0 |
| 5 | 4,970,574,495 | 9,221,683,693 | 0 / 0 |
| 6 | 4,903,502,270 | 9,269,702,204 | 0 / 0 |
| 7 | 4,938,164,780 | 9,208,413,193 | 0 / 0 |

Every attempt in this cohort is retained, without retries or exclusions. The
median paired reduction is 46.47%; that differs from the table's ratio of
medians. The conservative observed ratio is **0.540859334**, satisfying the
integer gate `10 * max(Vox) <= 9 * min(Brave)`. All browser, benchmark and
guard exits are zero. No engine optimization is implemented or credited.

## Workload and readiness

The source is Vox's existing successful-page cache. Its 137,106-byte HTML has
SHA-256 `4107cafa0e130f6f604ee2763c575669748a8ff21269d39b4a85cddb1d23fa40`.
Freezing removes 17 script elements and installs the original base URL. The
117,609-byte derivative has SHA-256
`a432e6846a949c02957b4e880300e588c1e0b4829276daee44d4c9ae100a7e90`.
Its supplied UTF-8 content type describes a static derivative, rather than
claiming the original main response headers. The cached markup contains account
UI, but no cookies are imported and current authenticated access is unverified.

The sealed archive contains **120 successful resource responses** from cached
encoded bodies and acquired missing static assets. Both engines consume the
same archived bytes and resource headers. Missing requests fail offline.
Vox receives a fresh copy of the encoded resource cache; Brave uses CDP replay
with its cache and service workers disabled. Neither receives a saved-page
raster or decoded-image cache. Every process has an empty private profile;
ambient proxy, heap, scripting and capture overrides are removed. Operating-
system filesystem and shader caches are retained.

The viewport is 1024×768 CSS pixels at capture scale 1. Before counts, separate
diagnostics verify complete documents, all 25 posts, both loaded HTML images
and exact cross-browser pixels; both images were inspected. That Brave PNG
becomes the fixed shared reference before the seven-pair cohort. During every
trial, native and CDP audits verify the document URL, `programming` title,
complete readiness, viewport and all post identities. Native audits additionally
require a fully active document with paint commands. No pixels or content are
masked, and no reference or tolerance changes during the cohort.

## Counter scope, build and host

The counter is macOS `proc_pid_rusage/RUSAGE_INFO_V4/ri_instructions`, sampled
every 5 ms. Primary totals include startup for both engines. Vox ends after
native capture, its content audit and teardown, with the root read as an
unreaped zombie. Brave ends at the last completed sampler pass before its PNG
CDP response; its subsequent content audit and verified shutdown are excluded.
Its navigation-only delta stays supplementary. GPU execution, external system
services and observer/replay work are excluded.

Both process-tree totals are observed polling lower bounds. Both observed Vox
tasks have final readings in all seven trials; Brave's missing final-sample
counts are 1, 2, 2, 1, 1, 1, 2. No counter reads are denied. The gate compares
observed counts conservatively; it does not certify an upper bound on unseen
short-lived Vox children.

The latest available signed production bundle is pinned in
`Build/old-reddit-instructions-20261101/measured/Vox.app` while another shared
build is in progress. No new production build is requested. The executable
SHA-256 is `cdca80b1d73a31d1685ce3b64d79002887a91332612c9e958596cf14e9d51c52`;
the native Skia library is
`9b8e9c151e1fc21590758626150a0c79314dc7e4084a2b29748b9b90098b541b`.
Brave is 156.1.98.60, reporting Chromium 156.0.8078.48. Runtime pins include
transitive native dependencies, Vox's helper/snapshot, Brave's framework, the
checker and measurement sources, and remain stable throughout the cohort.

The host has 18 logical CPUs. One-minute load averages range from **57.62 to
66.23**, with independent work active. This substantial contention is retained
in every observation and earns no elapsed-time or engine-optimization claim.
The unchanged 12 GiB process-tree guard observes **1,265.47 MiB** peak RSS over
70.83 seconds and exits zero. These observations establish this cached workload's
result under the recorded conditions, rather than a cold-system guarantee.

## Verification and reproduction

All **74 focused checks** pass for the Reddit/Wikipedia/CNN drivers and shared
observer/counter code. The tooling addition in `68eb2c7f` derives the expected
title and ordered post IDs from the input, rejects incomplete/error documents,
records host load/timestamps and accepts an explicitly pinned pixel checker.
No runtime savings advance the broad regression ledger.

Raw private HTML, resources, PNGs, exact commands, audits, process counters and
guard receipts are retained under mode-0700
`Build/old-reddit-instructions-20261101/`. No account-bearing input or screenshot
is committed. The durable [result](benchmark-results/old-reddit-programming-instructions-2026-11-01.json)
contains all counts, identities, coverage, acquisition failures and artifact
hashes without the account markup. Reproduce using new output and receipt names:

```sh
python3 tools/run_memory_bounded.py \
  --lock Build/reddit-programming-repeat.lock \
  --report Build/reddit-programming-repeat-guard.json -- \
  python3 tools/reddit_browser_instructions.py \
  --html Build/old-reddit-instructions-20261101/frozen.html \
  --expected Build/old-reddit-instructions-20261101/diagnostic/brave.png \
  --cache Build/old-reddit-instructions-20261101/frozen-cache \
  --output Build/reddit-programming-repeat \
  --vox Build/old-reddit-instructions-20261101/measured/Vox.app/Contents/MacOS/Vox \
  --network-deny Build/wikipedia-instructions-20261101/network-deny.dylib \
  --diff-tool Build/wikipedia-instructions-20261101/pixel_diff \
  --repeat 7 --required-reduction .10
```
