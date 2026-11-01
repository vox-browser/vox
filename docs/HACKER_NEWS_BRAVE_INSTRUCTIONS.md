# Hacker News instructions against Brave, 2026-11-01

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
    --lock Build/hn-repeat.lock --report Build/hn-repeat-guard.json -- \
  python3 tools/hacker_news_browser_instructions.py \
    --output Build/hn-repeat \
    --home-archive Tests/Browser/Brave/hn-home-instructions \
    --target-vox-fraction .9 --instruction-scope navigation \
    --diff-tool Build/hn-home-instructions-20261031/pixel_diff
```
