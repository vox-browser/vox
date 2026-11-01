# Hacker News scrolling

The production build measures **115.65 / 113.14 scroll-changing publications/s**
on the live homepage, with p95 intervals of **10.74 / 11.67 ms**, below the
16.67 ms budget in both fresh-process trials. This meets the measured native
60 FPS target for the conditions below; physical display scanout is unmeasured.
Occasional deadline misses and initial publication gaps remain.

[Durable receipts](benchmark-results/hacker-news-scroll-2026-11-01.json) and
[compressed raw observations](benchmark-results/hacker-news-scroll-2026-11-01-raw.json.gz)
retain all attempts, commands, identities, counters, host conditions and exits.
Full PNGs, build outputs and logs remain in `Build/hn-scroll60-20261101/`.

## Live production results

| Trial | Scroll FPS | Median / p95 / max interval | Intervals over 16.67 ms | Inputs / total publications |
| --- | ---: | ---: | ---: | ---: |
| 1 | 115.65 | 8.39 / 10.74 / 18.28 ms | 0.17% | 1200 / 1213 |
| 2 | 113.14 | 8.39 / 11.67 / 18.14 ms | 2.27% | 1200 / 1201 |

Each trial uses live `https://news.ycombinator.com/`, JavaScript enabled,
a 1024×768 document viewport at native scale 2, a fresh empty private profile
and cache, direct networking, and 20 seconds settling after the HN title.
No allowlist override is present. A read-only document audit at ten seconds
precedes input in both runs and confirms complete readiness and 30 unique
story IDs. Selected JavaScript policy does not establish VM performance.

Inputs are 1,200 precise native wheel events at nominal 120 Hz, delta 1,
reversing every 120 events. Actual delivery is 116.23 / 118.38 Hz. The entire
input windows are 10.315 / 10.129 seconds, with 1,193 / 1,146 scroll-changing
publications. Leading publication gaps are 42.54 / 36.01 ms; the first counted
scroll changes arrive after 58.44 / 51.66 ms. Trailing gaps are 0.30 / 0.17 ms.
Animations and the completion tail do not inflate scroll FPS. The 18-CPU host's
load averages fall from 13.05 to 10.94 and 10.94 to 8.37 during the trials.
These observations do not promise every interval stays inside the budget.

The executable SHA-256 is `47a6b90f38920a7b950ed48775b5feadc5f4d5bdb68251a1bab6e9eeed26633b`; its Skia bridge is
`14c3896931934e842701cffb2184f3e7a07a0059f38b68dfd7d45b9cb2c7562c`. The copy used for these fresh processes has exactly the installed
bundle's executable and native-library hashes at cohort start. Both browser
exits, the benchmark controller and the memory guard exit zero; all identities
stay unchanged during the cohort. The shared build guard was busy with another
session, so no duplicate production build was queued.

## Frozen page

The existing six-response archive retains its author scripts. Trials use a
1024×768 document viewport at native scale 2, fresh processes, private profiles
and resource caches, no external network fallback, and 20 seconds settling after
the Hacker News title. OS filesystem and shader caches remain. The host has
18 CPUs; exact load averages, timestamps, identities, inputs and frames are
retained in the receipts. Other sessions were compiling and running browsers;
these observations do not establish an isolated cache speedup.

The original catalog protocol sends 600 precise native wheel events at nominal
60 Hz, delta 2, reversing every 60 inputs. All four alternating trials remain:

| Trial | Control FPS | Cached glyph blobs FPS | Control / candidate median layer duration | Control / candidate p95 scroll interval |
| --- | ---: | ---: | ---: | ---: |
| 1 | 59.30 | 59.70 | 5.183 / 4.642 ms | 21.03 / 18.26 ms |
| 2 | 59.79 | 59.80 | 4.792 / 5.018 ms | 20.82 / 25.09 ms |

The second pair regresses in layer duration and interval timing. Strict
16.67 ms misses remain in this timer-limited workload; it does not establish
uniform frame spacing. The initial two production baselines already measured
59.89 / 59.80 FPS before this cache change. The old catalog's 46.1–51.5 result
belongs to an older executable and remains in the
[historical report](OPTIMIZED_SITES_SCROLL_FPS.md). Its improvement cannot be
credited to this change.

A separate protocol increases input resolution: 1,200 events at nominal 120 Hz,
delta 1, reversing every 120 events. Its intended velocity, range and ten-second
input duration match the original protocol. Actual input delivery is retained;
it is never assumed to equal the requested rate. This protocol was declared
before its four alternating trials:

| Trial | Control FPS | Cached glyph blobs FPS | Control / candidate p95 interval | Control / candidate intervals over 16.67 ms |
| --- | ---: | ---: | ---: | ---: |
| 1 | 117.38 | 117.71 | 10.08 / 9.97 ms | 0.25% / 0.00% |
| 2 | 107.49 | 112.55 | 16.49 / 11.98 ms | 4.33% / 1.82% |

Both controls also exceed 60 FPS. Control variation and host contention limit
attribution; higher input frequency alone earns no engine optimization credit.
These are gentle repeated sweeps around 0–252 CSS pixels, not rapid full-page
traversal or fling scrolling. Idle-tail frames prove completion and are excluded
from throughput. The first publication provides only the reference position.

## Implementation and checks

`58e8d7fb` retains immutable positioned Skia glyph blobs across frame replay.
Previously each visible run rebuilt and copied a blob before looking up the
existing raster cache. Identity includes the full font, glyph values and
positions after the same float conversion consumed by Skia. Paint, origin,
transform, clipping and backdrop decisions still run for each draw. The LRU is
bounded by 1,024 entries and an 8 MiB conservative charge; oversized runs render
without retention. Graphics-memory purging releases both caches.

A separate diagnostic resets cache counts after the native input-start marker:
58,068 hits in 58,112 requests, with 197 entries charged 864,432 bytes. These
post-start totals include the completion tail. A separate V `-profile` run resets
at the first wheel input and records 120 wheel calls, 156 draws and 37,876 native
glyph-run calls, including completion-tail draws. A four-second native sample
during input independently identifies glyph replay as active work. Profiles are
diagnostic; none supplies unprofiled FPS credit.

The profiler's production-O3 build hit the unchanged 12 GiB memory guard. Its
retained generated C was compiled separately at O0 for diagnosis. Three manual
link attempts failed before using the compiler's complete native dependency
plan. Those failures and actual exits remain recorded.

Ownership, font changes, mutable input buffers, float conversion, byte/count
limits, LRU eviction and explicit release pass focused checks. Normal and
ASan/UBSan runs each pass 6,240 exact native glyph comparisons against the pinned
control library. Five full HN viewport comparisons at scroll offsets 0, 21, 42,
126 and 252 preserve every one of 3,145,728 pixels and all 30 story IDs, with no
reference or tolerance changes. The first screenshot attempt incorrectly used
112 pixels of chrome: screenshot mode has 84, giving a 796-pixel document. It
failed the viewport audit and is retained. Corrected captures use an observed
1024×768 document; ordinary scrolling retains its observed 112-pixel chrome.

Live validation also exposed a catalog omission: Hacker News was documented as
optimized but absent from `optimizedsites.sites`. Normal navigation was blocked;
screenshot mode bypassed that restriction. The failed 150-second ordinary run
is retained. The catalog now includes its exact host and an original bundled
favicon, with host-spoofing, bookmark routing, migration and offline decoding
checks. Existing user bookmark edits remain preserved.

The first parallel package-test attempt hit the 3 GiB guard. A serialized run
then exposed unresolved native bridge symbols in the compiler's cached test
path. The explicit C/Clang, no-cache run passes all five bookmark/catalog test
files; the native shell and offline-icon test binaries also execute successfully.
The archived SVG logo did not decode through the favicon path, so its failed
checks are retained and the final catalog bundles the site's original ICO.

Production verification found a separate build issue. The implicit compiler
path returned success and stable source hashes while its executable still
reported three catalog entries and blocked Hacker News. Emitting complete C
from the same checkout showed the four-entry initializer. The production script
now explicitly selects `-b c -cc clang`, matching the focused checks. The rebuilt
runtime reports four entries, allows the HN address, and decodes the bundled
7,527-byte ICO to 256×256 with the exact asset SHA-256. The final build's generated C was inspected during compilation and contains
the four-entry initializer; the stock script removes its temporary directory
after packaging. A separate complete C-only emission remains in the artifacts. A subsequent
raw-ICO-byte assertion was too strict for compiled embedded data and failed
after the production shell had exited zero. Its original controller/guard exits
remain; runtime catalog and decoded-asset checks pass independently.

The shared production build includes concurrent work. Its receipt lists the
seven files changed during compilation, including initial-frame and retained
layout work. The final result applies to the pinned executable and embedded
libraries; it cannot isolate the incremental effect of the glyph cache, compiler
selection or those other changes. Shared build-lock contention is retained.
The completed production snapshot has exactly the installed bundle's bytes at
the start of live validation; fresh processes use that immutable copy while
another session owns the shared build guard.

The final production snapshot also preserves all pixels against the unchanged
control captures at scroll offsets 0 and 252, with complete 30-story audits.
No reference or tolerance was adjusted. Instruction counts were not remeasured
or credited, so no retired-instruction savings are added to the broad-check
cadence. The catalog's CPU row still refers to its historical pinned cohort.

Reproduce the live protocol using a fresh output path and completed bundle:

```sh
env -u ALL_PROXY -u HTTP_PROXY -u HTTPS_PROXY \
    -u all_proxy -u http_proxy -u https_proxy \
  python3 tools/run_memory_bounded.py \
    --lock Build/hn-live-UNIQUE.lock --report Build/hn-live-UNIQUE-guard.json -- \
  python3 tools/measure_precise_scroll.py \
    --binary Build/v/Vox.app/Contents/MacOS/Vox \
    --url https://news.ycombinator.com/ --output Build/hn-live-UNIQUE \
    --width 1024 --height 768 --chrome-height 112 \
    --inputs 1200 --input-hz 120 --delta 1 --reverse-every 120 \
    --require-title 'Hacker News' --settle-seconds 20 --script-policy enabled \
    --network-policy 'Live HTTPS; fresh private profile/cache; OS caches retained'
```

The recorded final commands additionally include the read-only pre-input content
audits described above. Compare frozen controls with identical input schedules;
do not compare the 120 Hz live result directly with Brave's traced CDP column or
attribute its difference from the old 60 Hz result to the cache.

A later shared executable (`af46b81773fa96d7c20c06cbd943c32fcca71effd03ec033cdc1b21d2d14b3dc`)
also passes a separate live load/input smoke: fresh empty profile, correct
viewport/title, 60 completed precise inputs, scroll movement and normal exit.
That short diagnostic is retained without acceptance FPS credit; the two-trial
range above belongs to the pinned production snapshot, not every later build.

Implementation commits: glyph retention `58e8d7fb`, HN catalog/icon `01eda037`,
and explicit production C/Clang selection `8da83a2e`. The profiler-reset
measurement support is `cd250d8d` and only activates in diagnostic runs.
