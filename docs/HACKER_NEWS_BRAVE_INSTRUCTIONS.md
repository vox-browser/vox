# Hacker News instructions against Brave, 2026-11-01

The subsequent `v -profile` investigation retains the transparent-gradient
optimization in `215b6e4`. Its matched Vox median decreases from
**4,268,701,477.5 to 4,237,070,157 instructions (0.741%)**. Brave's median
lower bound is **1,384,856,453.5**. The requested 10% advantage over Brave
remains **open**. The implementation, validation and full retained results
are described below; the earlier measurements remain historical evidence.

## V-profile continuation

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

The requested 10% navigation instruction reduction remains **open**. Eight
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
default remains `navigation`; a successful startup statistic cannot silently
pass its gate. All 49 focused benchmark, process-counter and coalition-counter
tests pass. No reference, tolerance, scripting policy, or production browser
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
limitation must be repaired before using LaunchServices cohorts as memory-bound
acceptance runs. The empty system sampler graphs and crashed asynchronous LLDB
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
    --memory-guard-registry Build/hn-repeat-pids.json \
    --home-archive Tests/Browser/Brave/hn-home-instructions \
    --target-vox-fraction .9 --instruction-scope navigation \
    --diff-tool Build/hn-home-instructions-20261031/pixel_diff
```
