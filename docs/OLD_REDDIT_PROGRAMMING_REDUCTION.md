# Old Reddit /r/programming instruction reduction, 2026-11-04

On a refreshed frozen `/r/programming/` workload, the Vox median fell from
**3,430,344,655** to **3,060,307,260** observed retired instructions between two
seven-pair cohorts: **10.79% fewer** by the ratio of medians. Brave's medians are
9,264,078,669 and 9,374,680,561, so Vox now uses **67.36% fewer** instructions
than Brave (63.0% before). Every Vox capture in both cohorts is pixel-identical
to the same fixed Vox reference.

The stricter comparison of the highest final Vox count with the lowest baseline
Vox count is 9.996%: `10 × 3,076,449,194 = 30,764,491,940` exceeds
`9 × 3,418,127,239 = 30,763,145,151` by 1,346,789. The 10% target is met by the
median and missed by the worst/best bound. No attempt was retried or excluded.

| Pair | Baseline Vox | Baseline Brave | Final Vox | Final Brave |
| --- | ---: | ---: | ---: | ---: |
| 1 | 3,437,632,620 | 9,267,495,354 | 3,076,449,194 | 9,357,237,558 |
| 2 | 3,418,799,406 | 9,199,598,151 | 3,061,349,870 | 9,395,437,084 |
| 3 | 3,430,344,655 | 9,114,214,268 | 3,061,657,728 | 9,374,680,561 |
| 4 | 3,427,339,220 | 9,218,185,929 | 3,052,480,072 | 9,358,630,492 |
| 5 | 3,418,127,239 | 9,264,078,669 | 3,050,879,758 | 9,341,279,262 |
| 6 | 3,443,554,566 | 9,340,494,120 | 3,057,779,505 | 9,441,108,163 |
| 7 | 3,446,540,287 | 9,399,441,384 | 3,060,307,260 | 9,390,569,365 |

## Attribution

Both cohorts use the shared `Build/v/Vox.app` (baseline executable SHA-256
prefix `1afe2dcde727d994`, final `d63e1dc8049e8fef`). Other sessions committed
between them, including the warm arena-reset change `ce8ee0c1d`, so the total is
not credited to this work alone. Median per-phase deltas from the native markers:

| Phase | Baseline | Final | Change |
| --- | ---: | ---: | ---: |
| Launch through `startup` | 437.7M | 298.3M | −139.4M |
| Parse and stylesheet preload | 402.7M | 356.6M | −46.1M |
| Style (`build_boxes`) | 501.4M | 447.6M | −53.8M |
| Layout and paint commands | 244.4M | 177.8M | −66.6M |
| AppKit launch and first frame preparation | 894.2M | 881.6M | −12.6M |
| Frames through capture start | 607.1M | 549.4M | −57.7M |
| Capture and PNG encoding | 82.6M | 82.8M | +0.2M |

The changes from this work:

- `b7ab66b8f` loads libcurl on the first network font or script fetch. Vox
  linked libcurl with OpenSSL, HTTP/2, HTTP/3 and compression libraries, and its
  font transport called `curl_global_init` at launch. Direct launches restart
  once for the compact allocator, so dyld mapped this stack twice. Measured dyld
  cost of that library group is about 55M per image, plus 13.8M in
  `curl_global_init`. Documents, subresources and images use browsernet, so this
  script-free page never loads curl. Pages that run fetch/XHR/workers or fetch web
  fonts load it on first use.
- `891c11fb8` prefetches backgrounds for the first page. A command-line launch
  installs its document before the native context exists; both prefetch paths
  returned early, and the first replay requested five background images and painted
  the whole document a second time when they arrived. A same-binary A/B using the
  existing `VOX_DISABLE_*PREFETCH` switches measures 3,188,538,181 versus
  3,227,621,159 (medians of three, −39.1M); the third frame disappears.
- `acaeba7b4` skips stylesheet invalidation before a document's first style
  update. Each initial sheet walked the document matching trailing universal and
  pseudo-element rules although no element had computed style. About 20M by
  profile; not isolated by A/B.
- `ad6a31fd1` binds the static HarfBuzz archive's unused FreeType backend to the
  vcpkg FreeType that Skia already loads, removing Homebrew FreeType, libpng and
  Brotli from each launch image: 9.3M per image by a dyld test, twice per direct
  launch.

The launch phase's −139.4M matches the predicted libcurl and FreeType savings.
Together these changes account for roughly 200M of the 370M; the remaining
reduction in style, layout and frames comes from concurrent commits.

A rejected attempt overrode `+[NSWritingToolsCoordinator isWritingToolsAvailable]`.
It removed 70M from `finishLaunching`, but `+[NSTextInputContext initialize]`
loads the same Writing Tools UI framework later; the same-binary total was
unchanged, so it was reverted and not committed.

## Remaining launch costs found

- **LaunchServices environment.** This machine has about 300 registrations of
  `Vox.app`/Ladybird bundles, mostly deleted `Build/` copies. AppKit's
  `_initializeSafeAperture` and `NSWindowResolvedScaleFactor` look up the app's
  own bundle node, and LaunchServices compares aliases across those records. The
  same binary run from a clone with a different bundle name spends 2.7M instead
  of 184M in `_initializeSafeAperture` and 98M instead of 159M in the first
  window's initialization: about 240M (7%) of each Vox observation here. Brave and
  a normal single installation do not pay it. Re-registering `Build/v/Vox.app`
  does not help; unregistering stale paths would, but changes the measurement
  environment and was not done.
- **Allocator restart.** Direct launches `execv` once to apply
  `MallocSpaceEfficient=1`; dyld maps every library before the restart, about
  125M after these changes. LaunchServices launches already receive the setting
  from `LSEnvironment`. The policy still lowers this page's peak footprint from
  about 352 MB to 333–336 MB, so it is retained.
- First-launch Skia Graphite pipeline creation (SkSL module parsing, MSL
  compilation and Metal pipelines for two Graphite backends) is about 120M per
  run with fresh caches; per-tile image draws read back from the GPU.

## Workload, scope and reproduction

The page was fetched on 2026-11-04 with the already imported Reddit session,
because anonymous requests now redirect to login. Freezing removes all 17
script elements and installs the original base URL (source SHA-256
`e8ffb950f17bf25a339791238eb7b9618d878fe735b3557deca0c45c4b356f73`, frozen
`a1b991bdea72f51b02b812012e7691065b67f95e9d5a6b3411f15e67c0a1d2e1`). Vox
populated a private resource cache once with network access; three assets only
Brave requests (tracking pixel, favicon and manifest) were acquired and added.
Both engines replay the same 20 sealed responses offline. The account-bearing
page, cache and PNGs stay in mode-0700 `Build/reddit-programming-10pct-20261104/`.

Vox and Brave differ in 2,046 pixels (two wrapped title lines: Vox breaks inside
`(youtube.com)` and keeps one title line Brave wraps). The driver therefore uses
per-engine fixed references (`--expected-vox`, `f9d21f4ee`); this is per-engine
stability, not cross-browser equality. Audits verify the `programming` title,
complete readiness, the 1024×768 viewport and all 25 post IDs in order.

Counters, endpoints and policies are those of the
[2026-11-03 recheck](OLD_REDDIT_PROGRAMMING_RECHECK.md): process-tree
`ri_instructions` sampled every 5 ms from launch, Vox through capture, audit
and exit, Brave through the last sample before its PNG response; both are polling
lower bounds, and GPU and outside services are excluded. Vox selects
JavaScriptCore; no page script runs. Brave is 156.1.98.60. One-minute loads were
9.2–15.1 (baseline) and 22.0–25.0 (final) on 18 logical CPUs; the 12 GiB guard
observed 1,295 and 1,293 MiB peaks and exited 0. Raw counts and PNG hashes are in
[the durable record](benchmark-results/old-reddit-programming-reduction-2026-11-04.json).

```sh
D=Build/reddit-programming-10pct-20261104
env -u ALL_PROXY -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u http_proxy -u https_proxy \
  python3 tools/run_memory_bounded.py --lock Build/reddit-UNIQUE.lock \
    --report Build/reddit-UNIQUE-guard.json -- \
  python3 tools/reddit_browser_instructions.py --html $D/frozen.html \
    --expected $D/references/brave.png --expected-vox $D/references/vox.png \
    --cache $D/frozen-cache --output Build/reddit-UNIQUE \
    --network-deny $D/network-deny.dylib \
    --diff-tool Build/vlang-fps-20261103/pixel_diff --repeat 7 --required-reduction .10
```
