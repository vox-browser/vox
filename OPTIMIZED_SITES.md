# Optimized sites

Recorded workloads where Vox uses fewer CPU instructions than Brave. These
macOS comparisons cover browser startup through a completed document capture;
fewer instructions measure CPU work, rather than elapsed rendering time.
Results apply to the frozen page and pinned build in each linked report.
Provisional entries retain unresolved acceptance checks.

| Site | Recorded date | Trials per browser | Statistic | Vox instructions | Brave observed instructions | Fewer instructions | Vox RAM (MiB)‡ | Brave RAM (MiB)‡ | Vox scroll FPS | Brave scroll FPS† | Evidence |
| --- | --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Lobsters homepage | 2026-11-02 | 7 | Median | 8,082,180,934 | 27,446,683,211 | **70.55%** | 535.2 | 992.4 | — | — | [Comparison](docs/LOBSTERS_BRAVE_INSTRUCTIONS.md) |
| Old Reddit /r/programming/ | 2026-11-03 | 7 | Median | 3,953,436,832 | 9,327,192,427 | **57.61%** | 607.1 | 608.3 | 39.2–53.0 | 59.56–59.78 | [Recheck](docs/OLD_REDDIT_PROGRAMMING_RECHECK.md), [earlier cohort](docs/OLD_REDDIT_PROGRAMMING_INSTRUCTIONS.md) |
| Hacker News homepage | 2026-11-01 | 7 | Median | 4,877,590,820 | 8,554,149,229 | **42.98%** | 559.7 | 639.2 | 59.7–59.8 | 59.78–59.79 | [Comparison](docs/HACKER_NEWS_BRAVE_INSTRUCTIONS.md), [scrolling](docs/HACKER_NEWS_SCROLLING.md) |
| CNN homepage (provisional) | 2026-11-01 | 7 | Median | 21,805,542,771 | 32,665,051,523 | **33.25%** | 1,234.0 | 1,031.5 | — | — | [Comparison](docs/CNN_INSTRUCTIONS.md), [receipts](docs/benchmark-results/cnn-home-thirty-percent-2026-11-01.json) |
| Wikipedia portal (www.wikipedia.org) | 2026-11-01 | 7 | Median | 6,686,475,010 | 9,702,898,348 | **31.09%** | 515.1 | 614.2 | 3.1–3.6 | 59.57–59.79 | [Audit](docs/OPTIMIZED_SITES_AUDIT.md), [comparison](docs/WIKIPEDIA_BRAVE_INSTRUCTIONS.md) |
| vlang.io (CLI protocol) | 2026-11-01 | 7 | Mean | 8.630 billion | 10.500 billion | **17.81%** | 709.6 | 668.9 | 0.8–0.9 | 59.49–59.79 | [Audit](docs/OPTIMIZED_SITES_AUDIT.md), [comparison](docs/VLANG_RENDERING_INSTRUCTIONS.md) |

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
| Archived homepage, fresh launch through encoded document PNG | 7 | **3,060,115,612** | **3,087,147,950** | 3.2B reached; **2.7B target open** | [Validated result](docs/HACKER_NEWS_3_2B.md), [2.7B continuation](docs/HACKER_NEWS_2_7B.md) |

The ongoing 2.7B work's latest complete default-production cohort measures
**2,713,777,398 median / 2,737,710,296 maximum** (2026-11-03), with exact original
pixels, all 30 stories, identity, ownership and normal exits in seven launches.
The **2.7B target remains open**. A separate seven-pair PNG diagnostic saves
12.4M between medians, with two pair regressions; its lossless compressed stream
is 8.68% larger and stays within the existing size bound. Compiling the same
native sources with `-O3` saves another 14.6M between seven matched medians
(six improving pairs, one regression), reaching a diagnostic 2.709B median and
2.724B maximum. These overrides have no final default-build credit yet.
Failed cohorts and rejected font/text/capture prototypes remain
recorded. PNG metadata is stable against a newly pinned control PNG; the
historical Vox PNG and earlier raw directory are unavailable after shared Build
cleanup. Regression suites remain deferred by the user's instruction, so the
fully validated row above stays unchanged. See the
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
fixed pixel reference. All seven Vox captures are exact. CNN scrolling is unmeasured.

FPS ranges span **two completed trials** per browser/page; the trial counts and
mean/median labels above refer to instructions. The [Vox scrolling report](docs/OPTIMIZED_SITES_SCROLL_FPS.md)
records native Cocoa input and changed-layer publications; the
[Hacker News follow-up](docs/HACKER_NEWS_SCROLLING.md) supplies its newer Vox range. **† Brave uses CDP
wheel input and Chromium presentation feedback, with frame-event tracing enabled**;
see its [report and raw evidence](docs/BRAVE_SCROLL_FPS.md). This bypasses Cocoa
input and observes a later frame boundary, so these columns do not establish a
matched FPS ratio or optimization acceptance. For the measured FPS rows, both
browsers use the same frozen page,
1024×768 document viewport, native scale 2, 600 alternating wheel inputs and a
full input-window denominator. Neither endpoint measures physical display
scanout or establishes smooth 60 FPS. **— means unmeasured, not zero FPS.**

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

| Page | Recorded date | Vox scroll FPS | p95 interval, both trials | Intervals over 16.67 ms | Evidence |
| --- | --- | ---: | ---: | ---: | --- |
| Wikipedia English Main Page (live) | 2026-11-01 | **80.2–84.1** | 15.68 / 14.81 ms | 3.90% / 3.09% | [Report](docs/WIKIPEDIA_SCROLLING.md), [receipts](docs/benchmark-results/wikipedia-main-scroll-vprofile-20261101.json) |
| Hacker News homepage (live) | 2026-11-01 | **113.1–115.7** | 10.74 / 11.67 ms | 0.17% / 2.27% | [Report](docs/HACKER_NEWS_SCROLLING.md), [receipts](docs/benchmark-results/hacker-news-scroll-2026-11-01.json) |

**Wikipedia:** These two fresh installed-process trials count scroll-changing native layer
publications over the full input window. Each completes 600 precise wheel inputs
at nominal 120 Hz, delta 1, continuous forward motion, with a 1024×764 document
viewport at scale 2, fresh private profiles/caches and 12 seconds settling after
the Wikipedia title. The default Wikipedia script policy leaves its author-script
runtime uninitialized. The report retains median/maximum intervals, publication
counts and boundary gaps. Occasional longer intervals remain; physical display
scanout is unmeasured. This English Main Page result has a newer build and a
different workload from the frozen portal instruction/Brave comparisons above.

**Hacker News:** Two fresh processes of the completed installed production
snapshot each complete 1,200 precise native inputs at nominal 120 Hz, delta 1,
reversing every 120 events, with a 1024×768 document viewport at scale 2 and
20 seconds settling after the title. They use the live page, empty private
profiles/caches and normal site restrictions. The p95 intervals fit a 60 FPS
budget; occasional misses and initial publication gaps remain. This protocol
checks rendering headroom above 60 FPS; it differs from the 600-input, 60 Hz
frozen-page protocol in the main table. The frozen-page controls already approached
60 FPS before the glyph-cache change, so the report makes no isolated speedup
claim. Physical display scanout is unmeasured.

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

- **Old Reddit /r/programming/:** cached account-bearing markup, 17 executable
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
bytes and matching full uBlock Origin lists. A strict pass requires zero pixels
both from saved source to frozen Brave and from Vox to frozen Brave. Results
apply to each report's pinned build and captured viewport, with live scripting,
scrolling and whole-site behavior outside that claim.

| Site | Rendering checkpoint | Evidence |
| --- | --- | --- |
| [Hacker News](https://news.ycombinator.com/) | Strict pass, 0 pixels; current control also passes | [Current control](Build/engadget-next-20261103/baseline/summary.json) |
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
| [Engadget](https://www.engadget.com/) | Open: exact pinned native captures; 221 fresh-source pixels; Brave replay varies even warm | [Engadget checkpoint](docs/FORUM_NEWS_EXPANSION.md) |
| [The Register](https://www.theregister.com/) | Open: initial native gap 6,786; source gap 110,180 pixels | [Five-site baseline](docs/FORUM_NEWS_EXPANSION.md) |
| [Slate](https://slate.com/) | Open: initial native gap 221,448; source gap 19,064 pixels | [Five-site baseline](docs/FORUM_NEWS_EXPANSION.md) |
| [WIRED](https://www.wired.com/) | Open: frozen reference changes between captures | [Five-site baseline](docs/FORUM_NEWS_EXPANSION.md) |
