# Cached Hacker News home-page instructions

The target is a Vox instruction count at most 80% of Brave's, while preserving
the complete home page. It has **not passed** the comparison.

`Tests/Browser/Brave/hn-home-instructions/` contains the original home-page
response downloaded on 2026-10-31 and its five referenced resources. The sealed
archive records URL, response headers, body hashes and download provenance.
Original author scripts are retained. Repeated comparisons replay these bytes
over loopback HTTP; they do not download the changing live home page again.
The loopback origin differs from the original HTTPS origin.

The unchanged Brave reference is
`Tests/Browser/Brave/expected/hacker-news-home-instructions.png`. It uses a
1024×768 CSS viewport and the display's native 2× scale, with sRGB output.
Each observation verifies every pixel, all 30 story IDs in source order,
document readiness, URL, viewport, exclusive resource-coalition membership,
and successful process exit. Both browsers use fresh private app copies,
processes, profiles and caches, with alternating trial order.

```sh
env -u ALL_PROXY -u HTTP_PROXY -u HTTPS_PROXY \
    -u all_proxy -u http_proxy -u https_proxy \
  python3 tools/run_memory_bounded.py \
    --lock Build/hn-home-comparison.lock \
    --report Build/hn-home-comparison-guard.json -- \
  python3 tools/hacker_news_browser_instructions.py \
    --output Build/hn-home-comparison \
    --home-archive Tests/Browser/Brave/hn-home-instructions \
    --diff-tool Build/hn-home-instructions-20261031/pixel_diff
```

Use a new evidence directory and guard-report filename for each run. The
home-page default threshold is 0.8; the discussion-page default stays 0.9.
The gate compares the largest Vox count with the smallest Brave lower bound,
using integer arithmetic. Every attempt is retained. Missing counters, failed
loads, omitted stories, pixel mismatches and abnormal exits cannot pass.

The endpoint is navigation request through encoded PNG availability. Native
markers precede the file write; Brave's endpoint includes CDP base64/IPC
delivery and readiness polling. Vox requests navigation before its first
native window frame, whereas Brave creates and resizes a blank window before
navigation. Counts include filtering, native window work, layout, paint,
settlement and capture inside those boundaries. They are not an isolated
internal rendering comparison. Resource-coalition counters include owned
helpers, exited tasks, and coalition-owned Metal compiler and CascadeSets
update services, but exclude GPU execution and outside services. The two
system service executables are accepted only at their exact system paths and
pinned when present. Other unaccounted executables still invalidate a run.

The initial valid three-pair comparison is retained under
`Build/hn-home-instructions-20261031/baseline-v2/`, with browser identities,
logs, raw counters, sampling bounds, content audits and exact pixel results.
Vox's median is 4,278,112,550 retired instructions. Brave lower bounds are
3,432,753,188; 3,384,594,163; and 1,499,422,091. The conservative ratio is
2.8621, exceeding the 0.8 target. The wide Brave variation must remain visible;
the slower Brave trials cannot be selected to claim success. The earlier
`baseline/` retains rejected Vox attempts caused by ambient proxy controls
and receives no complete-pair credit.

The baseline harness originally described its historical discussion fixture
as script-free. This home-page archive retains scripts; the subsequent shared
harness description and input metadata explicitly record that distinction.
No Vox optimization savings are credited by this cross-browser baseline.

## Rejected pixel-length projection experiment

A general fast path for projecting computed pixel lengths passed 36 focused
regressions in each memory mode, including fractional scales, source ownership
and property flags. The signed production candidate passed startup and had
stable build inputs. Its sole runtime source difference from the pinned
completed control was `css/device_layout_style.v`.

Five alternating matched trials did not show a repeatable improvement:

| Trial | Vox control | Vox candidate | Brave lower bound |
| --- | ---: | ---: | ---: |
| 1 | 13,392,288,152 | 13,588,867,416 | 3,377,259,363 |
| 2 | 4,252,428,764 | 4,201,602,490 | 3,348,724,152 |
| 3 | 4,261,465,367 | 4,245,284,513 | 1,338,719,067 |
| 4 | 4,218,982,048 | 4,226,092,956 | 1,444,786,185 |
| 5 | 4,225,965,040 | 4,261,672,682 | 1,335,935,369 |

All 15 observations exited successfully and matched the unchanged reference
pixels and every story ID. The candidate improved two of five pairs and
regressed three; paired savings were −196,579,264, +50,826,274, +16,180,854,
−7,110,908 and −35,707,642 instructions. The median difference was only
7,144,251 instructions (0.168%), while the median paired saving was negative.
The early large counts remain included; their cause has not been isolated.
The conservative candidate/Brave ratio was 10.1718, failing the 0.8 gate.

The speculative runtime change and its temporary test were removed. They earn
zero optimization credit, so the retained-savings broad-verification ledger
does not advance. The prior completed control bundle was restored atomically
after verifying that the installed executable still belonged to this
experiment. This experiment queued no further production build. Its executable SHA-256
is `233fbd2fac67f2695d49435fb6ea84f91c7fe958bfb83b24ac93a89fe125de86`.

Complete commands, build receipts, all counts and failures, host load records,
audits, PNGs, the rejected patch and restoration receipt remain under
`Build/hn-home-instructions-20261031/`. The successful cohort is `matched-v2/`.
The earlier `matched/` cohort remains rejected: its unexpected macOS
`SetStoreUpdateService` member triggered the old ownership gate, and one Vox
process finished before the observer could establish live membership.
The harness now explicitly accounts for that exact service and includes its
instructions in both browsers' totals. These are still full capture-workflow
counts, including startup and system-service variation within the recorded
boundaries. They do not isolate rendering or establish the requested 20% win.

The retained benchmark's 18 focused Python tests pass, including the new
service's exact membership and path checks. A subsequent shared production
build replaced the installed bundle after restoration. A fresh startup check
(PID 12740) passes for that later executable,
`dd50e4e7a7475a9b752ae1a09587e40f35f887f4e2f6dae9f7dea4d78c8f1d2d`;
the performance and pixel observations above belong to the pinned copies in
their evidence directories.

## Shared device-layout property pages

The follow-up retains scaled property pages in the document's style computer.
Styles sharing a source page can reuse its projection when the page contains
only context-independent pixel lengths and border-width keywords. Font-size
pages, relative or compound lengths, untyped values and animated styles keep
the ordinary resolver. Source-page generations reject recycled storage;
copy-on-write preserves cached pages when either style changes. The cache is
bounded to 4,096 entries. Arena builds retain only source pages owned by that
document or persistent initial pages, while the document's own arena is active.
The generation adds eight bytes to each
property page, increasing its size from 136 to 144 bytes.

The initial matched variant reused a shared production build containing those
exact CSS inputs. Its pinned executable is
`7b4b46acc46d444799d91bcaf0942857a25c41afea1cbd75bdfad741f5edcca7`.
The matched control uses that build's generated C, compiler arguments and
native libraries, with only the page-cache lookup and retention helper bodies
disabled. Both keep identical record layouts and generation bookkeeping; this
isolates cache reuse rather than measuring the complete storage change against
an older source revision. The installed bundle may subsequently change; all
results below belong to private pinned copies.

Final review added a stricter owner check: a child document's style computer
must not cache projected pages allocated in an active host arena. The new
regression fails on the initial variant and passes after checking the active
retained arena before publication. A fresh production build is necessary to
validate this guard; the initial variant's instruction counts below do not
establish instruction savings for the subsequent guarded executable.

A separate debugger run validates the executable UUID and the inlined cache-hit
branch at offset 4,480 in `css__computed_style_in_layout_coordinates`. It records
3,904 hits and an exact full-content capture. This diagnostic earns no timing
credit. Eight unprofiled matched trials retain the original scripts, resource
bytes, viewport, scale, private profiles, two-second settle period and PNG
endpoint. Every one of the 24 observations exits successfully, matches all
3,145,728 pixels and preserves all 30 story IDs.

| Trial | Cache-disabled control | Candidate | Brave lower bound |
| --- | ---: | ---: | ---: |
| 1 | 4,298,212,424 | 4,315,346,096 | 1,373,608,133 |
| 2 | 4,284,210,326 | 4,208,425,161 | 1,334,106,970 |
| 3 | 4,257,149,109 | 4,370,540,479 | 1,478,690,391 |
| 4 | 4,275,280,159 | 4,263,802,885 | 1,360,705,151 |
| 5 | 4,258,307,544 | 4,254,829,634 | 1,350,611,081 |
| 6 | 4,291,343,506 | 4,231,696,211 | 1,346,167,997 |
| 7 | 4,266,054,694 | 4,297,966,435 | 1,451,651,752 |
| 8 | 4,311,863,135 | 4,266,017,415 | 1,443,040,016 |

The initial construction segment, defined by the main-process
`unsized_script_images` through `build_boxes` checkpoints, improves in all
eight pairs. Its medians are 312,365,360.5 and 299,268,396.5 instructions,
a 13,096,964-instruction (4.193%) reduction. These checkpoints describe a
construction segment, not the entire navigation or an isolated browser-wide
rendering endpoint.

Full-window medians are 4,279,745,242.5 and 4,264,910,150 instructions: an
observed difference of 14,835,092.5 (0.347%). The candidate wins five pairs
and loses three. The median paired saving is 7,477,592; a deterministic
50,000-resample percentile bootstrap gives a 95% interval from −31,911,741
to +59,647,295. That variation prevents a reliable whole-page saving claim.
The host has 18 logical CPUs, recorded one-minute loads range from 13.71
to 16.27, and other compiler/browser work was present. Raw timestamps and
before/after loads remain attached to every observation.

Brave's median lower bound is 1,367,156,642 instructions. The conservative
candidate/Brave ratio is 3.2760, failing the unchanged 0.8 gate. The original
20% target remains open, and repeatable full-window optimization credit is zero.
The observed point difference exceeds the 5,000,000-instruction verification
threshold, so it triggered a broader regression batch despite that uncertainty.

The final owner guard passes 34 focused cases, including seven new cache cases,
in all three memory configurations. The new fixtures explicitly release their
document arenas. The arena-mode 63-case CSS and ten-case layout selections
were rerun after the guard and also pass.

The initial 33 focused cases, including six new cache cases, pass in default-GC,
no-GC and production-arena configurations. The broader 65-case CSS selection
passes in default-GC and no-GC modes. Its arena run passes 63 cases and fails
two existing snapshot assertions; a subsequent selection of those 63 cases
passes with an actual zero exit. Independent generated-C baselines remove the
feature's fields and generation updates and reproduce both failures:
`test_lazy_computed_geometry_and_provenance_outlive_paint_projection` and
`test_initial_scalar_snapshots_avoid_duplicate_permanent_hot_records`.

The 11-case layout selection passes ten default-GC cases and fails the existing
`test_device_layout_control_auto_sizes_use_the_projected_font_once` expectation:
165.5 versus 166 logical pixels. The generated-C baseline with the feature
removed reproduces that identical assertion. These baseline failures receive
no pass credit, and no original test or tolerance was changed to hide them.
The other ten layout cases also pass in no-GC and arena builds with actual
zero exits. All exclusions are explicit in the receipts; the complete failing
selections are retained, and they are not reported as wholesale passes.

Evidence is retained under `Build/hn-home-continue-20261031/`: `baseline-v2/`,
`candidate-pilot/`, `matched/`, `eligibility/`, generated candidate/control C,
exact compiler arguments, source hashes, build receipts, memory-guard exits,
focused/broad logs, and both baseline-failure comparisons. Earlier rejected
ambient-proxy and profiler attempts remain there as well. The benchmark's
18 focused Python tests pass. The initial timing comparison and the candidate
pilot each retain another six exact captures; neither substitutes for the
matched control/candidate measurements above.

The guarded bundle has executable SHA-256
`100c9efee3503e5357554e04646a994355a80f9bdefd2eae942facc96bf5a8c1`.
Its production script reaches signed completion, but the outer receipt job
exits 1 during its post-build snapshot because another session removed
`requestserver/curl_readiness_test.h` (and its test). That wrapper failure is
retained without pass credit. `candidate-build/reconciled-result.json` records
the missing/changed inputs and verifies that all four owned runtime sources
remained identical to the pre-build snapshot. Other concurrent runtime edits
prevent a full-tree source-stability claim. The completed bundle was pinned
independently, passed strict deep signature verification, and passed a fresh
headless startup under a separate 3 GiB guard with an actual zero exit.
All 21 guarded-build screenshot comparisons pass: 18 are pixel-exact and three
smoke cases use their existing platform bounds. The eight SVG mutation cases
and both turbulence cases are exact. No reference or tolerance was changed.
Another independent debugger check validates UUID
`E241FCB6-1566-35F8-8D63-42594DA31C69` and records the same 3,904 cache hits,
an exact home-page capture and all 30 story IDs. This confirms eligibility
after the owner guard, without supplying performance credit.

Three final unprofiled pairs on the guarded executable exit successfully and
match every pixel and story ID. Vox's median is 4,221,007,407 instructions;
Brave's median lower bound is 1,395,665,816. The conservative ratio is 3.1366,
so the comparison exits 1 solely for the unchanged 0.8 acceptance gate.
These observations are in `guarded-comparison/`. They verify the final bundle
against Brave; unrelated source changes between production builds prevent
attributing their difference from the earlier cohort to this cache.

Implementation and its focused regressions are committed as `cd48865e`.
The completed validation batch retains explicit baseline exclusions; it does
not claim a wholesale pass for the three unchanged failing tests. No further
whole-window instruction reduction is credited after this batch.
