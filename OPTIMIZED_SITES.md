# Optimized sites

Recorded workloads where Vox uses fewer CPU instructions than Brave. These
macOS comparisons cover browser startup through a completed document capture;
fewer instructions measure CPU work, rather than elapsed rendering time.
Results apply to the frozen page and pinned build in each linked report.
Provisional entries retain unresolved acceptance checks.

| Site | Recorded date | Trials per browser | Statistic | Vox instructions | Brave observed instructions | Fewer instructions | Vox RAM (MiB)‡ | Brave RAM (MiB)‡ | Vox scroll FPS§ | Vox GPU canvas FPS§ | Brave scroll FPS† | Evidence |
| --- | --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Hacker News homepage | 2026-11-04 | 7 | Median | 1,918,074,453 | 8,056,201,640 | **76.19%** | — | — | 39.2–43.8 frozen | 34.0–46.1 frozen (no canvas frames) | — | [Comparison](docs/HACKER_NEWS_BRAVE_INSTRUCTIONS.md), [ledger](docs/benchmark-results/hacker-news-1800-attempt-2026-11-04.json), [scrolling](docs/HACKER_NEWS_SCROLLING.md), [2026-11-05 FPS](docs/OPTIMIZED_SITES_SCROLL_FPS.md#current-build-2026-11-05) (RAM 559.7/639.2 MiB and scroll 59.7–59.8/59.78–59.79 FPS were measured on earlier builds; the current build repaints every frame, see the HN note below) |
| Lobsters homepage | 2026-11-02 | 7 | Median | 8,082,180,934 | 27,446,683,211 | **70.55%** | 535.2 | 992.4 | 59.0–59.6 live | 58.7–58.9 live (no canvas frames) | — | [Comparison](docs/LOBSTERS_BRAVE_INSTRUCTIONS.md), [2026-11-05 FPS](docs/OPTIMIZED_SITES_SCROLL_FPS.md#current-build-2026-11-05) |
| Old Reddit /r/programming/ | 2026-11-04 | 7 | Median | 3,060,307,260 | 9,374,680,561 | **67.36%** | — | — | — | — | — | [Reduction](docs/OLD_REDDIT_PROGRAMMING_REDUCTION.md), [ledger](docs/benchmark-results/old-reddit-programming-reduction-2026-11-04.json), [2026-11-03 recheck](docs/OLD_REDDIT_PROGRAMMING_RECHECK.md) (RAM 607.1/608.3 MiB, scroll 39.2–53.0/59.56–59.78 FPS on its earlier fixture; unmeasurable on 2026-11-05: fixture deleted, live page redirects guests to login) |
| CNN homepage (provisional) | 2026-11-01 | 7 | Median | 21,805,542,771 | 32,665,051,523 | **33.25%** | 1,234.0 | 1,031.5 | 33.1–35.9 live | 29.3–35.5 live (no canvas frames) | — | [Comparison](docs/CNN_INSTRUCTIONS.md), [receipts](docs/benchmark-results/cnn-home-thirty-percent-2026-11-01.json), [2026-11-05 FPS](docs/OPTIMIZED_SITES_SCROLL_FPS.md#current-build-2026-11-05) |
| Wikipedia portal (www.wikipedia.org) | 2026-11-01 | 7 | Median | 6,686,475,010 | 9,702,898,348 | **31.09%** | 515.1 | 614.2 | 59.2–59.8 live | 59.5–59.7 live | 59.57–59.79 frozen | [Audit](docs/OPTIMIZED_SITES_AUDIT.md), [comparison](docs/WIKIPEDIA_BRAVE_INSTRUCTIONS.md), [2026-11-05 FPS](docs/OPTIMIZED_SITES_SCROLL_FPS.md#current-build-2026-11-05) (frozen-fixture Vox 3.1–3.6 FPS on 2026-11-01) |
| vlang.io (CLI protocol) | 2026-11-01 | 7 | Mean | 8.630 billion | 10.500 billion | **17.81%** | 709.6 | 668.9 | 52.3–54.5 live | 54.8–55.7 live | 59.49–59.79 frozen | [Audit](docs/OPTIMIZED_SITES_AUDIT.md), [comparison](docs/VLANG_RENDERING_INSTRUCTIONS.md), [2026-11-05 FPS](docs/OPTIMIZED_SITES_SCROLL_FPS.md#current-build-2026-11-05), [GPU canvas](docs/VLANG_GPU_PASS.md) (frozen-fixture Vox 0.8–0.9 FPS on 2026-11-01) |

**Hacker News, current-Vox follow-up (2026-11-02):** the archived homepage's
startup-through-encoded-PNG median is **3,974,847,245**, **17.080% below** the
original Vox baseline of 4,793,590,625; the conservative historical reduction
is **16.115%**. Seven complete alternating encoder-control/default-Vox pairs
retain exact reference pixels and all 30 stories. This is a Vox-baseline
comparison; the additional Vox/Brave cohort failed one Brave ownership audit
and supplies no replacement for the historical Brave row. Author scripts execute
through JavaScriptCore. Live functional validation passes, while the instruction
claim remains frozen-page startup/capture work and establishes no rendering-time
or scrolling-FPS gain. See the [report](docs/HACKER_NEWS_VOX_REDUCTION.md) and
[raw counts](docs/performance/hn-vox-reduction-20261102.json).

**Hacker News, 3.2B target (2026-11-03):** seven fresh default-production launches
reach **3,060,115,612 median** and **3,087,147,950 maximum** observed coalition
instructions through encoded document PNG availability. Every trial passes exact
pixels, all 30 stories, PNG profile/density/metadata, ownership and normal-exit
audits. A separate seven-pair control/default cohort measures 3,133,122,728 →
3,061,561,124 medians; all fourteen output PNGs are byte-identical. Original
scripts run through JavaScriptCore. These are frozen-page startup/capture
results, with retained OS caches and excluded GPU/outside-service work, and
provide no new Brave ratio, isolated rendering time or scrolling-fps claim.
See the [report](docs/HACKER_NEWS_3_2B.md) and
[pinned evidence](docs/performance/hn-3200-progress-20261103.json).

**Hacker News, current Vox results:** the latest verified follow-up is listed
separately from the historical paired Vox/Brave row above.

| Workload | Trials | Vox median instructions | Vox maximum instructions | Status | Evidence |
| --- | ---: | ---: | ---: | --- | --- |
| Archived homepage, fresh launch through encoded document PNG | 7 | **3,060,115,612** | **3,087,147,950** | Earlier validated 3.2B result | [Validated result](docs/HACKER_NEWS_3_2B.md), [2.7B continuation](docs/HACKER_NEWS_2_7B.md) |
| Same archived homepage and capture scope, pinned build `db4eab23` | 7 | **2,655,492,802** | **2,676,747,832** | Packaged default build passes the 2.7B median/maximum gate | [Report](docs/HACKER_NEWS_2_7B.md), [evidence](docs/performance/hn-2700-resume-20261103.json) |
| Latest verified shared build `2e53ce13`, same workload | 7 | **2,675,233,606** | **2,701,876,818** | Median below 2.7B; maximum gate narrowly fails | [Retained cohort](docs/HACKER_NEWS_2_7B.md) |
| Same workload, shared build `9ebd66e2` (2026-11-04 baseline) | 7 | **2,720,274,906** | **2,737,779,104** | Brave median lower bound 8,109,046,423 | [Report](docs/HACKER_NEWS_BRAVE_INSTRUCTIONS.md) |
| Same workload, shared build `698536dc` with window-indexing opt-out `dd8ce6d7a` | 7 | **2,477,573,492** | **2,492,665,267** | 8.92% below the 2026-11-04 baseline; every launch passes the requested 5% ceiling | [Report](docs/HACKER_NEWS_BRAVE_INSTRUCTIONS.md), [ledger](docs/benchmark-results/hacker-news-window-indexing-2026-11-04.json) |
| Same workload, shared build `5283f5ee` with arena/font fixes `ce8ee0c1d`, `badeb3692`, `fbaa09e7a` | 7 | **2,415,799,258** | **2,423,249,629** | Second of two cohorts (first: 2,429,806,150 median); one Brave helper-ownership failure in each, so no Vox/Brave acceptance; 2.1B target open | [Report](docs/HACKER_NEWS_BRAVE_INSTRUCTIONS.md), [ledger](docs/benchmark-results/hacker-news-2100-progress-2026-11-04.json) |
| Same workload, shared build `5ec5d123` after the LaunchServices cleanup, ICU 78-only `fc6f92871` and toolbar glyphs `1faaf32c4` | 7 | **2,021,169,989** | **2,031,664,578** | Complete Vox/Brave cohort; Brave median lower bound 8,024,928,010; 2.1B target met | [Report](docs/HACKER_NEWS_BRAVE_INSTRUCTIONS.md), [ledger](docs/benchmark-results/hacker-news-2100-reached-2026-11-04.json) |
| Same workload, shared build `74270cfc` adding `07bc5117f` | 7 | **2,048,165,192** | **2,063,697,542** | Complete Vox/Brave cohort; Brave median lower bound 7,969,122,901; 2.1B target met | [Report](docs/HACKER_NEWS_BRAVE_INSTRUCTIONS.md), [ledger](docs/benchmark-results/hacker-news-2100-reached-2026-11-04.json) |
| Same workload, shared build `642ceefd` adding font order `4099177ce` | 7 | **2,011,557,697** | **2,090,182,179** | All Vox launches pass; one Brave helper-ownership failure, so no Vox/Brave acceptance | [Report](docs/HACKER_NEWS_BRAVE_INSTRUCTIONS.md), [ledger](docs/benchmark-results/hacker-news-2100-reached-2026-11-04.json) |
| Same workload, shared build `ad0e4e39` adding `1bc242c98`, `301f49be4`, `486ea20d4`, `a1f7527e0`, `b512ff759` | 7 | **1,918,074,453** | **1,927,596,995** | Complete Vox/Brave cohort; Brave median lower bound 8,056,201,640; 1.8B target not met | [Report](docs/HACKER_NEWS_BRAVE_INSTRUCTIONS.md), [ledger](docs/benchmark-results/hacker-news-1800-attempt-2026-11-04.json) |

The packaged `db4eab23` cohort passes with exact original pixels, all 30 stories
and ownership/identity/exit audits. The corrective private-codec change also
saves 35.1M between medians in seven matched diagnostic pairs. Two earlier
pinned default builds pass the target; the `8f1ee6b0`, `3fafbc61` and `2e53ce13`
maximum-gate failures remain recorded. The latter builds pass default packaged
startup/helper checks, all 21 rendering cases and live HTTPS navigation with
successful author-script execution; their high trials still exceed the ceiling.
Regression suites start only after the first passing default cohort, as the
user requested. Source, native memory-safety, font, filtering, UI2, PNG and
21-case rendering checks now pass. The PNG literal optimization trades an
8.68% larger compressed stream for less work, within the existing size bound.
Failed cohorts and rejected prototypes remain recorded. PNG metadata is stable
against a newly pinned control PNG; the historical Vox PNG and earlier raw
directory are unavailable after shared Build cleanup. These are frozen-page
startup/capture counts, with no new Brave ratio or scrolling claim. See the
[fresh evidence](docs/performance/hn-2700-resume-20261103.json),
[progress report](docs/HACKER_NEWS_2_7B.md) and
[all retained attempts](docs/performance/hn-2700-progress-20261103.json).

**Old Reddit /r/worldnews, Linux Vox follow-up (2026-11-02):** typeface reuse
reduced median **Cachegrind guest instruction references (Ir)** from
**7,181,198,185** to **5,794,954,378**, a **19.30%** reduction. The conservative
highest-candidate/lowest-control reduction is **13.19%**, also passing the
retained earlier-control gate. Three alternating Vox control/candidate pairs
preserve exact PNGs and audited content for the frozen 2024-01-01 script-free
fixture at 1280×900. Scope is program execution through exit after PNG capture
and audit, including startup and teardown. These software counts establish a
Linux Vox before/after improvement; they do not measure hardware-retired
instructions, live Reddit, native latency, or a new Brave comparison. Known
baseline rendering gaps remain. See the [report](docs/OLD_REDDIT_LINUX_TYPEFACE_CACHE.md)
and [raw-count ledger](docs/benchmark-results/old-reddit-linux-typeface-cache-2026-11-02.json).

**‡ RAM** is the median observed peak of simultaneous browser process-tree
physical footprints from separate **2026-11-02** measurements: two fresh pairs
per site, three for vlang.io. MiB means 1,048,576 bytes. Sampling covers root
discovery through browser exit, including capture/audits and observed browser
helpers/GPU processes; benchmark-tool memory is excluded. Early startup and
short-lived unsampled helpers can be missed. These current-build RAM runs use
the saved workloads and do not replace the instruction cohorts above. All
selected documents pass complete semantic audits; CNN, vlang.io and Brave's
Wikipedia capture differ from historical pixel references. See the
[RAM report](docs/OPTIMIZED_SITES_MEMORY.md) and
[raw values and receipts](docs/benchmark-results/optimized-sites-memory-2026-11-02.json).

**CNN is provisional:** its median lead exceeds 30%, but the conservative gate
fails with two large owned-helper costs, and one Brave capture mismatches the
fixed pixel reference. All seven Vox captures are exact. CNN scrolling was measured
only on the live page (2026-11-05), not on the instruction fixture.

**§ Vox scroll FPS (2026-11-05)** ranges span **two completed trials** per
column; the trial counts and mean/median labels above refer to instructions.
Both Vox columns use the shared production build `9e052f2b…` (head
`c0203bb8e`), fresh processes and private profiles/caches, a 1024×768 document
viewport at native scale 2, 20 seconds settling after the title and 600 precise
native wheel inputs at nominal 60 Hz, delta 2, reversing every 60 inputs. They
count scroll-changing native layer publications over the full input window.
**Vox GPU canvas FPS** sets `VOX_EXPERIMENT_GPU_CANVAS=1`, alternating with the
default control on the same bundle. A separate verification run per page shows
that the canvas engages only on the Wikipedia portal (598 frames, at most 1
level of difference) and vlang.io (1,054 frames; three frames differ by up to
58 levels at isolated anti-aliased edge pixels). On every other page both
columns measure the same code path, so their difference is run-to-run variation.
Hacker News uses its frozen archive; the frozen fixtures of the other rows were
deleted by `Build/` cleanup, so those values come from the **live** pages and
differ from the instruction workloads. Host load averages were 4.6–13.6 on 18
CPUs. See the [Vox scrolling report](docs/OPTIMIZED_SITES_SCROLL_FPS.md#current-build-2026-11-05)
and [receipt](docs/performance/optimized-sites-scroll-20261105.json).

**Hacker News regression:** every HN frame is now a complete repaint of about
25 ms. Scroll-raster reuse rejects each frame with
`nonviewport-vertical-scrollbar`, so HN falls from the earlier 59.7–59.8 FPS
(frozen, 60 Hz) and 113.1–115.7 FPS (live, 120 Hz) to the values listed here.
A layout-only reproduction does not show the rejected scrollbar; the browser-path
cause is open.

**† Brave uses CDP wheel input and Chromium presentation feedback, with
frame-event tracing enabled**; see its [report and raw evidence](docs/BRAVE_SCROLL_FPS.md).
Its values are the 2026-11-01 measurements on the since-deleted frozen pages.
This bypasses Cocoa input and observes a later frame boundary, so the Brave and
Vox columns do not establish a matched FPS ratio or optimization acceptance.
Neither endpoint measures physical display scanout or establishes smooth 60 FPS.
**— means unmeasured, not zero FPS.**

Percentages compare the two browser summaries in the same row. Means and
medians are labeled separately; the vlang.io means are rounded. Instruction
captures use a 1024×768 CSS-pixel viewport. Hacker News uses native capture scale 2;
the other workloads use scale 1. Old Reddit, Wikipedia and vlang.io use process-tree counters:
Vox includes capture and teardown, while Brave ends before shutdown. Both sums
are observed lower bounds because short-lived unsampled children can be missed.
Hacker News, CNN and Lobsters use exclusive resource-coalition counters through PNG availability,
including exited helpers and explicitly allowed coalition-owned system services;
Vox ends before the PNG file write and Brave includes CDP screenshot delivery.
GPU execution and services outside the recorded ownership scope are excluded.
The reports retain exact endpoints, identities and counter limits.

Lobsters uses its dated frozen guest DOM with author scripts removed, normal
scripting and filtering scriptlets retained, full-uBO filtering, and private
copies of complete encoded-resource caches. All 14 captures match the original
live Brave reference exactly. Its conservative highest-Vox/lowest-Brave lead is
69.28%; the existing completed production build already passes the 10% target.

## Latest live scrolling

| Page | Recorded date | Vox scroll FPS | p95 interval, both trials | Intervals over 16.67 ms | Vox GPU canvas FPS | Evidence |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| Wikipedia English Main Page (live) | 2026-11-05 | **64.3–83.3** | 20.87 / 15.48 ms | 18.98% / 2.37% | 68.8–82.0 (no canvas frames) | [Report](docs/OPTIMIZED_SITES_SCROLL_FPS.md#current-build-2026-11-05), [receipt](docs/performance/optimized-sites-scroll-20261105.json); 2026-11-01: 80.2–84.1, [report](docs/WIKIPEDIA_SCROLLING.md) |
| Hacker News homepage (live) | 2026-11-05 | **39.3–40.3** | 31.13 / 32.42 ms | 100% / 100% | 38.2–39.6 (no canvas frames) | [Report](docs/OPTIMIZED_SITES_SCROLL_FPS.md#current-build-2026-11-05), [receipt](docs/performance/optimized-sites-scroll-20261105.json); 2026-11-01: 113.1–115.7, [report](docs/HACKER_NEWS_SCROLLING.md) |

**Wikipedia:** These two fresh installed-process trials count scroll-changing native layer
publications over the full input window. Each completes 600 precise wheel inputs
at nominal 120 Hz, delta 1, continuous forward motion, with a 1024×764 document
viewport at scale 2, fresh private profiles/caches and 12 seconds settling after
the Wikipedia title. The default Wikipedia script policy leaves its author-script
runtime uninitialized. The report retains median/maximum intervals, publication
counts and boundary gaps. Occasional longer intervals remain; physical display
scanout is unmeasured. This English Main Page result has a different workload
from the portal row above. The 2026-11-05 trials ran on the shared build
`9e052f2b…` at host load 9.8–11.8; their actual input delivery (70–98 Hz)
varied with that load, so the range is wider than on 2026-11-01.

**Hacker News:** Two fresh processes of the completed installed production
snapshot each complete 1,200 precise native inputs at nominal 120 Hz, delta 1,
reversing every 120 events, with a 1024×768 document viewport at scale 2 and
20 seconds settling after the title. They use the live page, empty private
profiles/caches and normal site restrictions. This protocol checks rendering
headroom above 60 FPS; it differs from the 600-input, 60 Hz frozen-page protocol
in the main table. On 2026-11-01 the p95 intervals fit a 60 FPS budget. On the
2026-11-05 build every interval misses it: each frame is a complete repaint
(see the Hacker News regression note above). Physical display scanout is
unmeasured.

## How to benchmark against Brave

Use the following procedure before adding or updating a result. The full
repository requirements are in [AGENTS.md](AGENTS.md#cpu-instruction-comparisons-against-brave).

1. **Choose the scope before measuring.** The default is a fresh browser launch
   through completed document PNG capture, including startup and window/target
   setup in both engines. Use cumulative process/coalition readings; subtracting
   a post-launch baseline removes startup. Record whether encoding, CDP delivery,
   content audits and teardown are included. A navigation-only comparison needs
   equivalent initialized windows and matching boundaries in both browsers.
   Hacker News's old navigation markers included window setup only for Vox;
   use its `--instruction-scope launch` acceptance mode.
2. **Pin the browsers and inputs.** Reuse the latest successfully completed
   production bundle, following the shared-build rules; pin a completed copy
   when isolating a change. Record executable and transitive native-library
   hashes, helpers, Brave's framework/version, HTML/resource hashes, references
   and measurement sources. Launch fresh processes and verify identities
   throughout the cohort. An older build cannot validate newer engine code.
3. **Match the workload.** Use the same frozen bytes, author-script policy,
   viewport, backing/capture scale and settle conditions. Record both browsers'
   filtering policies. Give every trial fresh private profiles/caches, remove
   ambient measurement and proxy overrides, and replay archived responses
   without live fallback.
   State whether OS filesystem/shader caches are retained. Record host CPU
   count, load and timestamps. Validate live behavior separately before making
   a live-site claim; an archived or script-stripped page has that limited scope.
4. **Verify JavaScript activity separately.** Record the selected backend and
   script policy. Vox's selectors are `javascriptcore` and `libjs`; Brave uses
   V8. A selector or `--enable-javascript` does not prove execution: independently
   verify runtime initialization, actual code execution and absence of fallback.
   Keep probes outside the measured cohort and report unsupported DOM/script
   behavior. A script-free page whose runtime stays uninitialized measures
   startup/rendering, not JavaScript execution speed. See the
   [Old Reddit runtime probes](docs/OLD_REDDIT_ENGINE_COMPARISON.md).
5. **Validate content and pixels.** Establish fixed references before the cohort.
   Require the intended URL/title, complete readiness, correct viewport and full
   content identity, such as every post/story ID in order. Reject error pages,
   missing content, crashes and abnormal/unknown exits. Check unchanged pixel
   references for every capture. Per-engine reference stability is distinct
   from cross-browser pixel equality; disclose any difference and never change
   references, masks or tolerances to obtain instruction credit.
6. **Use matching counters and memory guards.** Use the same hardware-counter
   backend and ownership policy for both engines. Account for exited helpers
   where supported; disclose missing samples and excluded GPU/outside-service
   work. Both polled process-tree totals are lower bounds, so do not call a Vox
   observation an upper bound without proof. Run under
   `tools/run_memory_bounded.py` with its default 12 GiB budget. LaunchServices
   runs also need the same private PID registry passed as `--adopt-pids-from`
   to the guard and `--memory-guard-registry` to the supporting harness; verify
   adoption and browser RSS accounting.
7. **Collect at least seven complete alternating pairs.** For multiple Vox
   backends, rotate matched configurations and Brave controls. Keep every
   attempt, including first-launch outliers, failures and regressions; do not
   retry or exclude samples to pass. Profile with `v -profile` or other probes
   in separate diagnostic runs. Attribute an optimization only when its path
   executes on this workload and matched unprofiled controls support the gain.
8. **Compute and retain the result.** For a 10% target, require
   `10 * max(Vox) <= 9 * min(Brave)` using exact integer arithmetic; use Vox's
   upper and Brave's lower readings when intervals are available. Honor a
   different requested threshold explicitly. A gate on polled lower-bound totals
   is an **observed-count comparison**, not a certified
   bound on total work. Report the highest-Vox/lowest-Brave ratio as well as
   medians. The catalog percentage is `100 * (1 - statistic(Vox) / statistic(Brave))`,
   using the same declared mean or median and unrounded counts; paired reductions
   are a separate statistic. Preserve raw commands, logs, counters, PNGs, audits,
   identities, host conditions and actual browser/benchmark/guard exits in a
   unique `Build/` directory, with durable counts and hashes linked from the
   report. Keep private account-bearing artifacts out of commits. Preserve
   earlier failing cohorts, and qualify the result by its build, workload and
   cache conditions. Changing measurement boundaries earns no engine speedup.

For example, replay the archived Hacker News homepage with fresh output,
receipt and registry names (replace `UNIQUE` on every run):

```sh
env -u ALL_PROXY -u HTTP_PROXY -u HTTPS_PROXY \
    -u all_proxy -u http_proxy -u https_proxy \
  python3 tools/run_memory_bounded.py \
    --lock Build/hn-brave-UNIQUE.lock \
    --report Build/hn-brave-UNIQUE-guard.json \
    --adopt-pids-from Build/hn-brave-UNIQUE-pids.json -- \
  python3 tools/hacker_news_browser_instructions.py \
    --output Build/hn-brave-UNIQUE \
    --memory-guard-registry Build/hn-brave-UNIQUE-pids.json \
    --home-archive Tests/Browser/Brave/hn-home-instructions \
    --instruction-scope launch --target-vox-fraction .9 --repeat 7 \
    --scale 2 --settle-seconds 2 \
    --diff-tool Build/hn-home-instructions-20261031/pixel_diff
```

Use an existing verified pixel-diff binary. For other rows, use the linked
report's own fixture, references and harness. The [Old Reddit recipe](docs/OLD_REDDIT_PROGRAMMING_INSTRUCTIONS.md#verification-and-reproduction)
accepts `--vox-js-engine javascriptcore` or `--vox-js-engine libjs`, with
`--repeat 7 --required-reduction .10`; record runtime eligibility for either.
Keep the existing focused checks and broad-regression cadence from `AGENTS.md`.

For scroll FPS, follow the [scrolling measurement rules](AGENTS.md#scrolling-performance-measurements)
and use [precise native input](tools/measure_precise_scroll.py) or the
[disk-replay runner](docs/DISK_SCROLL_BENCHMARK.md) for Vox. Use the listed page
and pinned builds; match viewport, scale and input schedule between browsers,
with at least two complete unprofiled trials each. Count
scroll-changing native frame publications over the entire first-to-last input
window, verify movement and retain actual input times.
Link median/p95/maximum intervals, deadline misses, input/frame counts and
boundary gaps alongside FPS. State the endpoint for each browser; native
publication is distinct from physical display scanout. A Brave FPS value needs
its own matched measurement.

## Workload and rendering scope

- **Old Reddit /r/programming/ (2026-11-04):** a refreshed frozen page fetched
  with the imported session, all 17 script elements removed and 20 sealed
  responses replayed offline. Vox and Brave differ in two wrapped title lines
  (2,046 pixels), so captures are checked against fixed per-engine references;
  all 25 post IDs are preserved. Medians fall from 3,430,344,655 to
  3,060,307,260 (10.79%); the worst-final/best-baseline bound is 9.996%. About
  200M comes from four committed launch/paint changes and the rest from
  concurrent commits; RAM and scrolling were not remeasured on this fixture. See
  the [reduction report](docs/OLD_REDDIT_PROGRAMMING_REDUCTION.md).
- **Old Reddit /r/programming/ (earlier fixture):** cached account-bearing markup, 17 executable
  script elements removed, normal scripting policy retained, 120 sealed
  successful resource responses and fresh profiles/caches. All 14 captures
  match the same Brave reference exactly and preserve all 25 post IDs. The
  highest observed Vox count is **56.19% below the lowest Brave count** in the
  [2026-11-03 recheck](docs/OLD_REDDIT_PROGRAMMING_RECHECK.md). Live
  access is blocked by HTTP 403; no live or current-authentication claim is
  made. This new workload does not reverify the historical home-page fixture.
  The selected Vox page-script runtime is unused on this script-free fixture;
  the [JSC/LibJS selector comparison](docs/OLD_REDDIT_ENGINE_COMPARISON.md) is
  a configuration comparison, not a JavaScript-execution benchmark.
- **Hacker News:** the frozen original homepage and five resources, with author
  scripts enabled, fresh empty profiles/caches and two seconds of settlement.
  All 14 captures match the unchanged Brave reference at every pixel and retain
  all 30 story IDs. The highest Vox count is **41.61% below the lowest Brave
  bound**, passing the 10% target. The earlier 3× headline excluded Brave's
  window setup while including Vox's; the corrected startup scope includes
  setup for both. The same pinned binaries were reused, so the accounting
  correction receives no engine optimization credit. OS caches are retained;
  the report preserves earlier startup outliers and makes no cold-system claim.
- **Wikipedia:** original archived responses, fresh empty profiles/caches,
  JavaScript disabled in both browsers, matching Vox's existing Wikipedia
  policy. All 14 captures match their respective engine baselines exactly;
  seven pixels at the search-box corners differ between engines. Even the
  highest observed Vox count is **29.81% below the lowest observed Brave count**
  in the fresh audit, which records successful browser exits. A separate live
  navigation using the measured capture path matches the frozen Vox pixels.
  The existing production build already met the target; this comparison
  required no runtime optimization.
- **CNN (provisional):** the frozen homepage has author scripts removed, with
  normal scripting policy, JavaScriptCore initialization, inline handlers and
  full-uBO filtering retained. Seven alternating pairs use original-origin
  replay, fresh private copies of the declared cache/profile templates,
  1024×768 at scale 1, five seconds of settlement and retained OS caches.
  All content/filter audits and actual browser exits pass. The highest Vox
  count, **36,373,350,927**, is **1.13119×** the lowest Brave lower bound,
  **32,154,975,008**, so the strict 30% target remains open. Brave pair 4 differs
  at 13,565 pixels; that failure and both Vox outliers remain in the statistics.
  The live-load check records frame and consent-API JavaScript errors; this
  frozen startup/capture result does not establish live author-script performance.
- **vlang.io:** an initialized DOM snapshot with archived assets, author scripts
  removed, animations/transitions disabled and a fixed video poster; JavaScript
  policy remains enabled. The fresh CLI audit records clean exits and exact
  matches to unchanged engine references in all 14 captures. The highest Vox
  count is **15.10% below the lowest Brave bound**. Cross-browser equality is
  unmet: 112,005 pixels differ, with maximum channel error 3. The earlier CLI
  cohort's 16.54% mean lead and the background cohort's **0.41% mean lead** both
  remain in the report. Launch-context dependence is unresolved; the table
  applies to the stated CLI protocol. Live author-script behavior is checked
  separately from these instruction measurements.

## Historical result awaiting raw verification

| Site | Recorded date | Trials per browser | Statistic | Vox instructions | Brave observed instructions | Fewer instructions | Vox scroll FPS | Brave scroll FPS | Evidence |
| --- | --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | --- |
| Old Reddit home | 2026-10-17 | 7 | Median | 6,289,762,769 | 8,208,707,273 | **23.38%** | — | — | [Historical comparison](docs/OLD_REDDIT_INSTRUCTIONS.md), [audit](docs/OPTIMIZED_SITES_AUDIT.md) |

The documented arithmetic and startup scope check out, but the private
`Build/reddit-parity/` fixture and per-process receipts are absent from this
checkout. This older home-page row is distinct from the newly measured
`/r/programming/` workload above and is not a freshly verified acceptance result. Its report
describes a frozen authenticated page with executable author scripts removed,
exact Brave-reference captures and a conservative 21.39% observed lead. Live
scripting, interactions and authentication parity are outside that record.

## Comparisons still open

[Pikabu](docs/PIKABU_INSTRUCTIONS.md) has a small, variable observed median lead
that does not establish a repeatable advantage. [CNN](docs/CNN_INSTRUCTIONS.md)
has the provisional median lead listed above; its strict 30% acceptance remains
open. [Stack Overflow on macOS](docs/STACKOVERFLOW_BRAVE_INSTRUCTIONS.md) has not
established lower instruction counts than Brave. The fresh seven-pair Stack
Overflow comparison records median observed counts of **27,723,596,574 for Vox**
and **10,379,419,729 for Brave**: Vox uses **2.67× as many instructions** on the
frozen questions page. All captures match their fixed per-engine references;
2,061 pixels differ across engines. The earlier
[PR diagnostic](docs/STACKOVERFLOW_MACOS_PR_COMPARISON.md) remains separate.
Stack Overflow's
[Linux optimization](docs/STACKOVERFLOW_LINUX_PERFORMANCE.md) compares two Vox
versions using Cachegrind instruction references, rather than Vox against Brave.

## Forum/news rendering coverage

All 15 sites from the forum/news session are in the
[test catalog](Tests/Browser/Brave/forum-news.json) and the bookmark-bar catalog.
The bar retains Wikipedia, Old Reddit `/r/programming/` and vlang.io too, and
lists Hacker News once. These entries track rendering work; the instruction
comparisons above retain their own acceptance requirements and measured pages.

The pixel checks use a frozen guest DOM at 1024×768, scale 1, original response
bytes and matching full uBlock Origin lists. New strict passes require zero
pixels from saved source to frozen Brave, from Vox to frozen Brave, and between
two fresh Brave replay processes. Older checkpoints retain their recorded
protocols. Results apply to each report's pinned build and captured viewport,
with live scripting, scrolling and whole-site behavior outside that claim.

| Site | Rendering checkpoint | Evidence |
| --- | --- | --- |
| [Hacker News](https://news.ycombinator.com/) | Strict pass, 0 pixels including fresh-process reference agreement | [Current control](docs/evidence/engadget-replay-gate-20261103.json) |
| [Reddit](https://www.reddit.com/) | Guest homepage blocked by HTTP 403; distinct from the measured Old Reddit programming page above | [Access record](docs/ADBLOCK_POPULAR_SITES.md) |
| [Lobsters](https://lobste.rs/) | Strict frozen-viewport pass, 0 pixels | [Original checkpoints](docs/ADBLOCK_POPULAR_SITES.md) |
| [Slashdot](https://slashdot.org/) | Strict frozen-viewport pass, 0 pixels | [Original checkpoints](docs/ADBLOCK_POPULAR_SITES.md) |
| [Stack Overflow](https://stackoverflow.com/questions) | Deferred in this pixel-parity session | [Original checkpoints](docs/ADBLOCK_POPULAR_SITES.md) |
| [BBC News](https://www.bbc.com/news) | Strict cold-cache pass, 0 pixels; fixed-metadata regression repaired | [Current checkpoint](docs/FORUM_NEWS_EXPANSION.md) |
| [CNN](https://edition.cnn.com/) | Vox/frozen Brave 0 pixels; saved-source fidelity still fails | [Source/media limits](docs/ADBLOCK_POPULAR_SITES.md) |
| [The Guardian](https://www.theguardian.com/international) | Strict frozen-viewport pass, 0 pixels | [Original checkpoints](docs/ADBLOCK_POPULAR_SITES.md) |
| [The Verge](https://www.theverge.com/) | Strict frozen-viewport pass, 0 pixels | [Original checkpoints](docs/ADBLOCK_POPULAR_SITES.md) |
| [Pikabu](https://pikabu.ru/) | Deferred in this pixel-parity session | [Original checkpoints](docs/ADBLOCK_POPULAR_SITES.md) |
| [TechCrunch](https://techcrunch.com/) | Open: 34,710 native pixels; source fidelity passes | [Current checkpoint](docs/FORUM_NEWS_EXPANSION.md) |
| [Engadget](https://www.engadget.com/) | Open: pinned cold/complete native 0; source gap 221; earlier replay variation retained | [Engadget checkpoint](docs/FORUM_NEWS_EXPANSION.md) |
| [The Register](https://www.theregister.com/) | Open: fresh candidate native 246 pixels; source/replay 0; SVG-picture fix awaits production validation | [Register checkpoint](docs/FORUM_NEWS_EXPANSION.md), [evidence](docs/evidence/register-parity-20261104.json) |
| [Slate](https://slate.com/) | Open source gate: cold/complete native 0, fresh Brave replay 0; saved-source gap 19,064 pixels on `6e17496f…` | [Slate checkpoint](docs/FORUM_NEWS_EXPANSION.md), [evidence](docs/evidence/slate-svg-publication-parity-20261104.json) |
| [WIRED](https://www.wired.com/) | Exact frozen first-frame guest viewport: cold/complete source/replay/native 0 on `aa370dd4…`; nine focused browser regressions exact; normal animation remains unstable | [WIRED checkpoint](docs/FORUM_NEWS_EXPANSION.md), [evidence](docs/evidence/wired-parity-20261104.json) |
