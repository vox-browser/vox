# Hacker News instructions against Brave, 2026-11-01

## 2026-11-04: 2.1B reached

The 2,100,000,000 target is met by two complete seven-pair cohorts:

| Cohort | Shared build | Vox median | Vox maximum | Brave median lower | Brave minimum lower | Fewer |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | `5ec5d123` (receipt `20261104-094434-5b2699fb`, HEAD `504cf01cc`) | **2,021,169,989** | 2,031,664,578 | 8,024,928,010 | 7,990,477,907 | 74.81% |
| 2 | `74270cfc` (receipt `20261104-100327-a67dd60d`, HEAD `1d8447382`) | **2,048,165,192** | 2,063,697,542 | 7,969,122,901 | 7,942,602,577 | 74.30% |

All 14 launches in each cohort exit cleanly, match the reference at every pixel
and retain all 30 story IDs; every helper stays in its coalition, so both are
complete Vox/Brave acceptance cohorts (`passed: true`, guard exit 0). The
conservative maximum-Vox/minimum-Brave ratios are 0.2543 and 0.2598. Host
one-minute load was 5.0–6.1 for cohort 1 and 12.3–13.3 for cohort 2, while other
sessions compiled. Both builds are dirty shared-tree builds that contain
concurrent sessions' work, so the drop from the previous section's 2,415,799,258
cannot be attributed only to the changes below.

**Environment.** With the user's approval, 699 LaunchServices bundle records whose
paths no longer existed were unregistered with `lsregister -u`. The ten Vox
bundles still on disk stayed registered. The earlier renamed-clone comparison
put this machine artifact at about 240M per Vox launch; it was not re-measured
separately. `tools/prune_stale_launchservices.py` (`684e1b64e`) reports new
stale records and, with `--apply`, unregisters only paths that are missing at
that moment. It reported none after these cohorts.

**Duplicate libraries.** The case-mapping bridge linked Homebrew ICU 79 while
everything else used the vcpkg ICU 78 build, so both copies loaded. `fc6f92871`
links the bridge to vcpkg ICU 78. `DYLD_PRINT_LIBRARIES` now shows one copy each of
ICU 78.2, freetype, libpng and brotli, besides the system's own `libicucore`
and ImageIO `libPng`. With `MallocSpaceEfficient=1` preset, as
LaunchServices supplies it, `Vox --no-such-option` now retires a median of
**143,727,433** instructions (seven launches on `69b3556c`), down from about 236M.
The drop also contains concurrent sessions' lazy libcurl loading and library
deduplication. Without the preset, Vox re-executes itself and the median is
252,502,360.

**Toolbar glyphs.** UI2's AppKit buttons and labels ignored
`TextStyle.font_family`, so `ⓘ`, `◎` and `◷` were measured in the system face,
which builds CoreText's fallback cascade (`TFontCascade::CreateFallback`).
`1faaf32c4` applies a declared family to native labels and buttons. The
history button names Menlo (pixel-identical), the address-bar `ⓘ` is a filled
UI2 vector path (at most 43/255 channel difference on 199 pixels), and the
bookmark placeholder is `○` instead of `◎`. `07bc5117f` stops UI2 from clearing an
image a button never had, which measured the title before the family was
applied. Probed `BrowserApp__mount_ui2_chrome` falls 112.5M → 109.4M → 100.6M.
One 33.7M fallback remained after `07bc5117f`: the tooltip installed later in
`render_element` measured the `◷` title in the 17 pt system face.
`4099177ce` applies the family right after native creation instead; updates
keep applying it. On `642ceefd` (receipt `20261104-102329-8a5408fe`) the probe
records no `CreateFallback` call, the mount falls to **63.8M**, and a chrome
capture is pixel-identical to the `1faaf32c4` build.

A seven-pair cohort on `642ceefd` measures a **Vox median of 2,011,557,697**
(maximum 2,090,182,179; all seven Vox launches pass pixels, stories and
ownership; load 14.9–15.9). It is not an acceptance cohort: Brave pair 3
failed its ownership audit because a helper left its coalition. It is
retained, and no replacement cohort was run.

**Not implemented.**

- JavaScript bytecode caching: system JavaScriptCore offers `JSScript` caching
  only through an entitled data vault and has no cache-path option.
  `JSC_reportParseTimes` and `JSC_reportBytecodeCompileTimes` put all parse and
  bytecode compilation on this page at about 13.5 ms (367 functions), so even
  a bootstrap rework is capped at roughly 35–45M.
- Style and layout: after the cached font matching above, the profile is flat
  and no single hotspot remains.
- Writing Tools: another session rejected the opt-out because its cost moves to
  `NSTextInputContext`.

Raw evidence is under `Build/hn-2100-20261104/` (`cohort3`, `cohort4`, `floor`,
`probe-*`). The [ledger](benchmark-results/hacker-news-2100-reached-2026-11-04.json)
retains every count, PNG hash, load, guard exit and probe, including the
incomplete cohort. Broad suites have not
run; the focused ICU, UI and bookmark tests pass in default and prealloc modes.

## 2026-11-04: progress toward 2.1B

The follow-up target is a Vox median of **2,100,000,000**. It remains open.
Two seven-pair cohorts on shared build `5283f5ee` (receipt
`20261104-082044-8804e823`, HEAD `fbaa09e7a`) measure Vox medians of
**2,429,806,150** and **2,415,799,258** (maximums 2,473,793,577 and
2,423,249,629), down from the 2,477,573,492 window-indexing cohort below.
All 14 Vox launches pass pixels, stories and exits. Brave medians are
8,234,549,289 and 8,183,702,872. Each cohort has one Brave launch whose
helper left its resource coalition, so neither is a complete Vox/Brave
acceptance cohort. One-minute host load was 29–54 while other sessions compiled.

Three commits address costs found with debugger-free CPU samples and
per-thread instruction probes:

- `ce8ee0c1d` stops remapping an arena with at least 1 MiB of capacity after a
  reset cycle that used no more than one 256 KiB scope block. Font scratch
  arenas reset once or twice per element, so a load made 1,734 `mmap` calls;
  it now makes 108. Three matched injected pairs on one executable estimate
  **33.8M** (median paired saving).
- `badeb3692` keeps the fallback sans-serif face's design-unit metrics instead
  of rereading and decoding the font file for every point size. Probed
  `fallback_font_pixel_metrics` falls **21.8M → 4.8M** (nine calls).
- `fbaa09e7a` caches CoreText family selection and the collection index
  per face. Probed `resolve_system_font_face` falls **21.1M → 14.3M** for
  the same 46 calls.

Concurrent sessions changed the same shared build, including lazy libcurl
loading (`b7ab66b8f`) and earlier background prefetching (`891c11fb8`).
The cohort-to-cohort difference therefore cannot be attributed only to
these commits. Focused prealloc and default-GC tests pass for all three
(arena, fallback metrics and CoreText suites); broad suites have not run.

Remaining measured costs, none changed here:

- Startup before page work: `Vox --no-such-option` retires about 236M,
  mostly dyld loading and initializers; `_vinit` is 33M, including a 15.9M
  user-agent stylesheet parse. ICU 78.2 and 79.1 are both loaded, as are
  duplicate freetype, libpng and brotli copies.
- The UI2 toolbar mount costs about 112M. CoreText's fallback cascade for
  the `ⓘ`, `◎` and `◷` glyphs is about 35M; UI2 buttons and labels ignore
  `TextStyle.font_family`.
- Every page parses a 241,996-byte bootstrap factory and a 68,721-byte state
  JSON (about 90M). The filter worker evaluates the 168 KB uBO engine (about
  130M) and checksums its 28.6 MB trie. The public JavaScriptCore SDK offers
  no bytecode cache.
- First glyph rasterization through CoreGraphics dominates painting.
- LaunchServices lists 475 `org.ladybirdbrowser.vox` registrations, 465 of them
  missing on disk, and launch-time bundle lookups compare them. This is a
  machine artifact and was not changed.

Rejected diagnostics: presetting `MallocSpaceEfficient` saves nothing,
because LaunchServices already supplies it through `LSEnvironment`. A
private no-op for AppKit's AppIntents registration saves only about 17M.
Raw evidence is under `Build/hn-2100-20261104/`; the
[ledger](benchmark-results/hacker-news-2100-progress-2026-11-04.json)
retains every count, probe and guard result.

## 2026-11-04: window-indexing opt-out

A fresh seven-pair cohort on the latest shared bundle (`9ebd66e2`, receipt
`20261104-054422-ce11c3fb`) measures a **Vox median of 2,720,274,906**
(maximum 2,737,779,104) against a **Brave median lower bound of 8,109,046,423**:
66.45% fewer instructions. The requested goal was a further 5% reduction, i.e. a
Vox median at or below 2,584,261,160.

Per-process sampling inside Vox's coalition shows macOS's CascadeSets
`SetStoreUpdateService` retiring **238.5–238.9M instructions per launch**, more
than the whole target. Debugger probes trace it to AppKit's
`UIIntelligenceIntents.WindowTabIndexer`. That indexer donates each window to
Spotlight as one `com.apple.window-tab` item, and CoreSpotlight's donation
starts that XPC service in the caller's coalition. AppKit re-donates on window
title changes; a five-title-change probe re-indexes four times. Brave pays the
same service. AppKit reads the `NSEnableWindowTabIndexing` default first. Vox
now registers `NO` in the registration domain before creating its first
window (`dd8ce6d7a`). Vox's tabs are UI2-owned, so only the window-title
Spotlight record is lost. An explicit
`defaults write org.ladybirdbrowser.vox NSEnableWindowTabIndexing -bool YES`
still re-enables it. The focused native window-state test checks the
registration domain and that precedence.

The candidate shared build (`698536dc`, receipt `20261104-071720-d70691ae`,
HEAD `dd8ce6d7a`) measures a **Vox median of 2,477,573,492** (maximum
2,492,665,267) against a **Brave median lower bound of 8,124,779,792**: **69.51%
fewer**. The conservative maximum-Vox/minimum-Brave ratio is 0.3084. The Vox
median falls by **242,701,414 (8.92%)**, and every candidate launch is below the
5% ceiling. All 28 captures in the two complete cohorts match the reference at
every pixel and retain all 30 story IDs. The candidate is a dirty shared-tree
build that also contains concurrent sessions' work. The isolated attribution is
therefore the matched comparison below.

On that same executable, seven alternating pairs inject either an
argument-domain `NSEnableWindowTabIndexing=YES` (AppKit's default restored) or
an injection-cost-only control. Medians are **2,744,315,387 indexing-on versus
2,486,520,559 default**. The paired saving is 233,942,141–263,303,719; its
median is **257,060,367**, and all seven pairs improve. All fourteen launches
pass pixels, stories, ownership and input pins. In correctly attached samples,
SetStoreUpdateService (238.9–240.7M) appears only in the indexing-on arm.
A diagnostic sampler in other trials attached to unrelated processes; those
per-process samples are inconclusive, while coalition counts are unaffected.

An earlier candidate cohort is retained and invalid: Brave pair 2 failed its
ownership audit because a Brave helper left its coalition. Its seven Vox launches
pass all gates, with a median of 2,477,230,135. Host one-minute load was
3.4–5.3 for the baseline but 10.9–15.8 for later runs, because other sessions
were compiling. The baseline/candidate loads are therefore unmatched. The matched
pairs share one load period and supply the attribution. OS filesystem/shader
caches were retained.
Three intervening shared builds were rejected before C preprocessing because
other sessions changed inputs; none is counted.

The baseline phase markers also show style/box construction at about 248M,
versus about 209M in the 2026-11-03 `codec-default` cohort. This regression comes
from concurrent work and is unchanged here. Raw evidence is under
`Build/hn-5pct-20261104/`; the durable
[ledger](benchmark-results/hacker-news-window-indexing-2026-11-04.json) retains
every count, identity, PNG hash and guard exit. These are frozen-page
startup/capture counts; GPU and services outside the coalition remain excluded.

Broad verification is partial. The default 11-case screenshot smoke set passes
on the later shared bundle `67a6b379` (HEAD `1ba30d7f`, containing the change):
8 cases are exact and 3 are within their existing tolerances. Full translation
batches, the LibJS AST corpus and broad SVG batches have not been run. This
change touches neither translated packages nor LibJS.

## 2026-11-01 scope correction

The previous headline of roughly three times Brave's instructions used
**asymmetric startup boundaries**. Wikipedia and Old Reddit count browser
startup; Hacker News subtracted it after Brave's window initialization but
before Vox's window initialization. That interval cannot establish comparable
page-only instruction costs. In the previous V-profile cohort it omitted a
median **7,124,921,654 instructions from Brave** and **638,105,410 from Vox**.
Those same observations already had full-startup medians of 4,873,836,713 for
Vox and 8,520,270,605 for Brave. The 3× headline was misleading.

Seven fresh alternating pairs using the **same pinned browser binaries** now
give startup-through-capture medians of **4,877,590,820 for Vox** and
**8,554,149,229 for Brave: 42.98% fewer instructions**. The highest Vox count
is 41.61% below the lowest Brave count, passing the requested 10% gate. All 14
captures match the unchanged Brave reference at every pixel and preserve all
30 story IDs. No engine optimization is credited for correcting the boundary.

## Scope correction and fresh measurements

The default in `tools/hacker_news_browser_instructions.py` is now `launch`,
with the requested 0.90 target for both home and discussion fixtures. Progress
output previously printed navigation counts even when `launch` was selected;
it now names the selected scope and prints both intervals separately. The
historical `--instruction-scope navigation` remains available as an explicitly
asymmetric diagnostic. No counters, original resources, scripts, reference
pixels, density, viewport or settle duration changed for this audit.

The selected interval uses the cumulative exclusive resource-coalition reading
from coalition creation through encoded document PNG availability, including
exited browser helpers and the explicitly allowed coalition-owned services.
Vox's endpoint precedes the PNG file write; Brave's includes CDP screenshot
delivery and its earlier target/window setup. GPU execution, outside services,
the observer and replay server are excluded. This measures browser startup and
capture workflows; it does not isolate parsing, layout or rendering.

| Pair | Vox startup instructions | Brave startup lower bound | Brave startup upper bound |
| --- | ---: | ---: | ---: |
| 1 | 4,939,453,409 | 20,414,767,238 | 20,431,126,782 |
| 2 | 4,879,036,590 | 8,540,690,999 | 8,542,775,446 |
| 3 | 4,857,481,030 | 8,653,965,214 | 8,668,202,072 |
| 4 | 4,873,871,013 | 8,529,961,814 | 8,559,949,963 |
| 5 | 4,877,590,820 | 8,554,149,229 | 8,571,099,582 |
| 6 | 4,883,764,693 | 8,459,695,225 | 8,474,754,507 |
| 7 | 4,870,785,476 | 8,629,219,677 | 8,659,612,151 |

Every observation is retained, including the first large Brave count. The
conservative maximum-Vox/minimum-Brave ratio is **0.583880776**, below 0.90.
All browser, benchmark and guard exit codes are zero. Fresh private browser
profiles and caches are used for every process; operating-system filesystem
and shader caches are not flushed. The host has 18 logical CPUs and recorded
one-minute load averages of 8.25–9.49. The adoption-aware 12 GiB memory guard
observes 907.53 MiB peak aggregate process-tree RSS over 58.81 seconds. No
elapsed-time improvement is claimed.

The audited Vox executable SHA-256 is
`ac11c56baaa7d18a5ee0275c45c1e7a3f5409b81b7db3d13d87939878c39f81d`,
with native Skia library
`d31bb4331568cf01992c47a020f55fcddd8fc8117872afd2f62937aacb55ac65`.
These are the earlier transparent-gradient candidate, reused to isolate the
measurement correction from unrelated shared production changes. Brave is
156.1.98.60 (Chromium 156.0.8078.48). Executable/library fingerprints remain
unchanged after every observation. No production build was requested or run.

This aligns the inclusion of startup with the
[Wikipedia](WIKIPEDIA_BRAVE_INSTRUCTIONS.md) and
[Old Reddit](OLD_REDDIT_INSTRUCTIONS.md) reports. Their process-tree counter
backend, 1× captures and scripting policies differ from this windowed 2×,
original-scripts-enabled workload. Cross-site instruction totals therefore
should not be treated as identical experiments.

The old candidate's first large Vox observation and its failing conservative
startup gate remain in the V-profile result below; this later cohort does not
erase that observation or establish a cold-system guarantee. The fresh
cohort's asymmetric navigation diagnostic still reports medians of
4,237,857,649 for Vox and 1,414,657,394 for Brave. Both intervals remain in
every result. A fair warm-navigation experiment would need to start both
browsers after equivalent window setup.

All raw commands, PID identities, membership audits, PNGs, counter brackets,
host loads and receipts are under `Build/hn-scope-audit-20261101/`. The durable
[scope audit](benchmark-results/hacker-news-scope-audit-2026-11-01.json)
retains all counts and artifact hashes. All 57 focused benchmark, memory-guard,
process-counter and coalition-counter tests pass, including the default-scope
regression. The tooling fix is `cb17c436`; no runtime savings accumulate toward
the next broad regression checkpoint.

## V-profile continuation

This historical cohort used the asymmetric navigation diagnostic. Its
within-Vox control/candidate comparison retains the transparent-gradient
optimization in `215b6e4`: the median decreases from 4,268,701,477.5 to
4,237,070,157 instructions (0.741%). Its cross-browser navigation ratio is
not a valid page-only cost comparison.

The diagnostic builds the canonical checkout with current V's **`-profile`**
for all functions, including inline functions. It produces 8,112 populated
function rows. Build outputs are isolated under
`Build/hn-vprofile-20261101/instrumented/`; the existing production application
is preserved. The guarded build completes in 292.46 seconds with 11.43 GiB
sampled peak process-tree RSS, inside the unchanged 12 GiB budget. The diagnostic
capture exits zero and matches the original Hacker News reference exactly.

The profile identifies 42 calls to `draw_native_css_gradient_tile`, initially
127.571 ms inclusive. The homepage's vote-arrow backgrounds include
`linear-gradient(transparent, transparent)`, which was still building shaders,
allocating raster storage and entering the native GPU renderer. The new native
gate returns successfully before that work for finite, zero-alpha CSS stops.
It preserves tiny nonzero alpha, invalid stops, SVG spread modes, and the
caller's surrounding clip/effect state.

A separate instrumented native library confirms **42 successful fast-path
uses** and an exact full-content capture. Source isolation verifies that the
matched control and candidate native inputs differ only by this gate and its
header include. Both applications share the same unprofiled V executable,
helper, other native libraries and resources. No source checkout or worktree
was copied.

A follow-up uses the same V-profile executable and switches only the matched
native libraries. Both report 42 gradient calls and 808 command draws. The
gradient wrapper's inclusive time is 229.611 ms for control and 0.267 ms for
candidate. **These are diagnostic elapsed times, not retired instructions or
whole-page savings.** V profiling has shared, non-thread-safe counters, and
other native timings vary substantially between those runs. No profiling
measurement contributes instruction-count credit.

Eight alternating unprofiled control/Brave/candidate triples retain every
observation, with no retries or exclusions:

| Trial | Vox control | Vox candidate | Brave lower bound | Paired instruction saving |
| --- | ---: | ---: | ---: | ---: |
| 1 | 4,312,688,821 | 12,422,457,130 | 1,490,046,281 | -8,109,768,309 |
| 2 | 4,255,677,098 | 4,222,571,609 | 1,385,150,503 | 33,105,489 |
| 3 | 4,268,624,967 | 4,207,813,654 | 1,404,552,953 | 60,811,313 |
| 4 | 4,268,915,261 | 4,259,673,883 | 1,311,470,117 | 9,241,378 |
| 5 | 4,253,174,120 | 4,246,734,028 | 1,384,428,954 | 6,440,092 |
| 6 | 4,268,777,988 | 4,224,735,354 | 1,378,065,027 | 44,042,634 |
| 7 | 4,246,577,351 | 4,243,383,944 | 1,407,594,981 | 3,193,407 |
| 8 | 4,306,634,509 | 4,230,756,370 | 1,384,562,404 | 75,878,139 |

The first candidate observation is a substantial regression, and its cause
is not isolated. Consequently, this does **not** establish a cold-start gain:
the arithmetic mean regresses by 984,631,982.125 instructions. Seven pairs
improve. The paired median saving is 21,173,433.5 instructions; a fixed-seed
50,000-resample percentile bootstrap interval is [3,193,407, 60,811,313]. The
difference between engine medians is 31,631,320.5 instructions. All 24 captures
match all 3,145,728 pixels and retain all 30 story IDs in source order, with
successful browser exits. The conservative candidate/Brave ratio is 9.4722,
which fails the unchanged 0.90 target. OS filesystem/shader caches are not
flushed; all browsers still receive fresh private profiles and caches.

The observed median reduction crosses the 5,000,000-instruction broad-check
threshold. Completed validation includes the focused native gate and its
actual bridge entry point, AddressSanitizer/UndefinedBehaviorSanitizer checks,
eight broader native gradient/text/SVG checks, and 21 screenshot comparisons.
Eighteen screenshots are exact; three default smoke cases pass their existing
platform bounds. The eight source/paint-server mutation cases and both
turbulence cases are exact. The broader region check includes 192 exact
integration comparisons, and the independent modern-Skia interpolation check
includes four exact GPU comparisons. Fresh headless startup and strict deep
signature verification pass. A fresh candidate process also loads the live
Hacker News homepage completely with 30 stories and zero reported JavaScript
errors; this receives no paired live instruction credit.

Initial test-launch failures are retained: strict compilation reported unused
functions in the included preexisting native implementation; its focused test
now explicitly suppresses that warning. The first broad interpolation command
selected old LibWeb Skia headers, and the first region launch omitted its
required reference-library environment. Corrected commands pass without changing
assertions or pixel tolerances. The initial nonzero receipts are not described
as successful whole-suite runs. After the completed broad checkpoint,
additional accumulated instruction savings for this slice are zero.

The memory-guard repair is committed separately as `0f56fb13`. A benchmark can
atomically register LaunchServices PIDs and their creation times through
`--memory-guard-registry`; the outer guard adopts them through
`--adopt-pids-from`. PID reuse does not adopt an unrelated process. Twenty-six
focused tests pass, including a real independently launched process exceeding
its memory budget. The final cohort's guard accounts for the reparented browser
trees, records all adopted identities, observes 896 MiB peak RSS and exits 1
because the benchmark's instruction target fails. These RSS observations do not
include non-descendant system services. The earlier guard limitation below
remains applicable to historical runs without adoption.

All commands, profiles, complete observations, failure receipts, pixel outputs,
compiler flags, executable/native identities and fixed-seed assessment are
under `Build/hn-vprofile-20261101/`. The durable
[V-profile result](benchmark-results/hacker-news-v-profile-2026-11-01.json)
records every count and artifact hashes. The accepted candidate is a pinned
completed app with the changed native library; it does not replace another
session's shared production bundle. The reproduction command below can use
`--vox-app Build/hn-vprofile-20261101/gradient-candidate/Vox.app`, with the same
private PID registry passed to the outer guard and benchmark.

## Initial comparison and removed experiments

The original asymmetric navigation diagnostic failed the 10% gate. Eight
alternating control/candidate/Brave trials retain a control Vox median of
**4,271,112,593.5** retired instructions and a Brave median lower bound of
**1,429,892,080.5**. Vox uses 2.987 times the instructions at this endpoint.
No runtime optimization from this investigation is retained or credited.

The measurement definition matters. Including each fresh browser's complete
startup through capture gives medians of **4,909,481,277** for Vox and
**8,576,464,123.5** for Brave: Vox's median is **42.76% lower**. This is a
different workload boundary. The navigation measurement includes Vox's native
window initialization after its navigation request, whereas Brave initializes
and resizes its blank window before `Page.navigate`. Startup totals include
Brave's target/window setup. Neither isolates parser/layout/rendering work.

The conservative maximum-Vox/minimum-Brave 0.90 gate fails at **both**
boundaries. All first, much larger observations remain included. Their cause
has not been isolated. A median startup advantage does not establish a
repeatable 10% navigation advantage or a cold-system startup guarantee.

| Trial | Vox control navigation | Vox candidate navigation | Brave navigation lower bound | Vox control startup | Brave startup lower bound |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 13,755,939,078 | 13,466,591,108 | 3,674,937,165 | 14,407,387,229 | 20,827,544,966 |
| 2 | 4,271,363,459 | 4,282,928,087 | 1,423,479,238 | 4,910,320,874 | 8,569,361,256 |
| 3 | 4,270,861,728 | 4,289,911,243 | 1,442,732,799 | 4,908,641,680 | 8,602,847,495 |
| 4 | 4,274,840,482 | 4,258,758,518 | 1,421,927,122 | 4,916,455,761 | 8,555,636,509 |
| 5 | 4,257,885,981 | 4,308,732,814 | 1,352,523,854 | 4,894,800,237 | 8,490,596,121 |
| 6 | 4,283,983,731 | 4,262,939,727 | 1,436,692,481 | 4,924,597,667 | 8,583,566,991 |
| 7 | 4,252,863,301 | 4,326,057,852 | 1,406,310,329 | 4,896,929,897 | 8,569,350,334 |
| 8 | 4,266,411,875 | 4,310,921,865 | 1,436,304,923 | 4,903,012,818 | 8,642,494,028 |

All 24 observations exit successfully and preserve the unchanged Brave reference
at all **3,145,728 pixels**, with all 30 story IDs in source order. Nothing is
masked or tolerated. The initial three-pair production baseline also has six
exact captures and a failing navigation gate; its Vox median is 4,328,861,454
and Brave median lower bound is 1,412,713,691. These initial observations are
retained separately, without replacing them with the later cohort.

The frozen original homepage and five resources come from
`Tests/Browser/Brave/hn-home-instructions`. Original author scripts execute.
The HTML SHA-256 is
`d5e63157ceadf74ed71d03dcce668588521fb18cf7479acf27c6c74344b2fc53`.
Both engines use loopback HTTP replay, fresh private profiles/caches, a
1024×768 CSS viewport, native 2× density, and two seconds of settlement.
Operating-system filesystem and shader caches are not flushed.

Hardware resource-coalition counters include exited owned helpers and the
explicitly allowed coalition-owned system services. GPU execution and services
outside that coalition are excluded. Brave's polling brackets produce a lower
and upper bound. Native Vox markers end after PNG encoding, before the file
write; Brave's endpoint includes delivery of its CDP screenshot response.
Content auditing follows the measured endpoint in both engines.

Two experiments were removed:

- Routing explicitly supplied opaque black glyph colors through the existing
  CPU path produced an exact diagnostic capture but no established saving.
- A bounded, owned cache of serialized font packets passed corrected native
  tests, including byte equivalence, eviction, retained packet lifetime and
  fallback. Its first test expected four system faces to fit in 32 MiB; the
  corrected multi-face test uses an explicit 128 MiB budget. The browser probe
  validates native-library UUID `45438B85-8D46-3766-A64B-963AD512A17D` and the
  actual entry/miss/hit addresses, and observes **zero calls and zero hits**.
  Consequently, it cannot explain differences on this workload. Its median
  navigation count increases to 4,299,322,028.5, with three improving and five
  regressing pairs. No performance credit or broad-verification ledger advance
  is justified.

The benchmark now records both instruction boundaries, each observation's
timestamp and host load, and an explicit `--instruction-scope` selection. The
default at that time was `navigation`; the scope correction above supersedes
that default without replacing historical results. All 49 focused benchmark,
process-counter and coalition-counter tests pass. No reference, tolerance,
scripting policy, or production browser
was changed. Broad runtime suites were not run for the removed experiments.

A fresh live navigation on the pinned production executable (PID 73300) exits
zero and audits `https://news.ycombinator.com/`, title `Hacker News`, complete
readiness, 30 stories and zero reported native JavaScript errors. It is a
document-load diagnostic, without cross-browser live performance credit.
Its guard observes 392.4 MiB peak process-tree RSS under a 3 GiB budget.
The earlier live wrapper's incorrect audit field name and nonzero exit are
retained alongside the corrected run.

Evidence is under `Build/hn-instructions-20261101/`. The durable
[machine-readable result](benchmark-results/hacker-news-macos-coalition-brave-2026-11-01.json)
contains every count, process identity, host load and artifact hashes. The
pinned production executable SHA-256 is
`068c409166506105949b7ba18416367c6fd5cfd1785fa78b38b308577c652356`.
Its native library control was compiled from the canonical checkout; the
candidate differs by the removed font cache. The shared production bundle was
left untouched, and no source checkout, worktree or duplicate production build
was created.

The outer memory guard records its command and actual nonzero benchmark exit
for the failed target, but its RSS excludes LaunchServices-reparented browsers.
That RSS is **not** a browser memory bound or peak measurement. Direct native
diagnostics and live subprocess launches are included in their guards. This
limitation was repaired in `0f56fb13` before the V-profile cohort and scope
audit above. The empty system sampler graphs and crashed asynchronous LLDB
sampler earn no profiling credit; the synchronous breakpoint probes succeed.

Reproduce with a fresh output directory and report filename:

```sh
env -u ALL_PROXY -u HTTP_PROXY -u HTTPS_PROXY \
    -u all_proxy -u http_proxy -u https_proxy \
  python3 tools/run_memory_bounded.py \
    --lock Build/hn-repeat.lock --report Build/hn-repeat-guard.json \
    --adopt-pids-from Build/hn-repeat-pids.json -- \
  python3 tools/hacker_news_browser_instructions.py \
    --output Build/hn-repeat \
    --vox-app Build/hn-vprofile-20261101/gradient-candidate/Vox.app \
    --brave-app 'Build/hn-vprofile-20261101/control-cohort/brave/Brave Browser.app' \
    --memory-guard-registry Build/hn-repeat-pids.json \
    --home-archive Tests/Browser/Brave/hn-home-instructions \
    --target-vox-fraction .9 --instruction-scope launch --repeat 7 \
    --diff-tool Build/hn-home-instructions-20261031/pixel_diff
```
