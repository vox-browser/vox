# Wikipedia without page JavaScript: memory

On 2026-10-18, five fresh alternating pairs measured **110.5 MB for Vox versus
382.6 MB for Chrome: 71.1% less settled physical memory**, with page JavaScript
disabled in both browsers. MB here means 1,000,000 bytes. All five Vox document
captures match the previous Vox baseline exactly.

| Pair | Vox settled bytes | Chrome settled bytes, JS off | Reduction |
| --- | ---: | ---: | ---: |
| 1 | 110,511,280 | 383,627,288 | 71.193% |
| 2 | 111,019,184 | 386,215,816 | 71.255% |
| 3 | 110,494,968 | 380,645,112 | 70.972% |
| 4 | 111,494,368 | 382,398,104 | 70.843% |
| 5 | 110,314,744 | 382,644,008 | 71.170% |
| Median | **110,511,280** | **382,644,008** | **71.119%** |

Both acceptance gates pass: the median Vox result is below 30% of Chrome's
median, and the largest Vox result (111,494,368 bytes) is below 30% of the
smallest Chrome result (380,645,112 bytes). The latter comparison saves
70.709%, with 2,699,165.6 bytes of margin below the target.

This is a settled-memory result. Median sampled launch peaks were **544.8 MB
for Vox and 779.4 MB for Chrome**; observed ranges were 531.4–559.5 MB and
776.3–784.3 MB respectively. These are simultaneous polling lower bounds,
reported separately. The work does not achieve a 70% reduction in startup peak.

## Conditions

Both browsers replay the same frozen `https://www.wikipedia.org/` page at
1024×768 CSS pixels and DPR 2: 40 cache files, 10 response bodies, declared
synthetic HTTP metadata, and no live fallback. The HTML SHA-256 is
`5c0de7d8a1af1dc8c06cc2a517265ff96db0ed11114a62be2625ed13c9cdb466`.
Both windows remain visible in the background during readiness and settled
measurement, away from the pointer, with matching activity checks. Chrome briefly
activates at launch, before the controlled interval. Chrome is for Testing
155.0.8059.79. The host is an
Apple M5 Max, 18 logical CPUs, 128 GiB RAM, macOS 26.5 (25F71), with shared
machine load recorded in the raw observations.

The strict v4 observer samples the simultaneous task physical footprint of the
browser and every discovered descendant, including GPU, renderer, utilities,
filter workers and discovered reparented helpers. WindowServer and shared system
services are excluded for both. Polling is requested every 5 ms; short-lived
processes between polls can be missed. Readiness is followed by 15 seconds of
settling, and the final-second median ends before screenshot allocation. RSS
and sums of unrelated task lifetime peaks are not the target metric.

Chrome disables page scripts before navigation and enables its script-based
document audit only after the memory endpoint. Vox reports no page runtime,
script sources, source bytes or script preloads. Font/resource/readiness,
density, activity and actual process-exit checks pass for every observation.
No GC overrides, manual benchmark collections or memory-profiler/ledger/GC
diagnostic injections are used. Vox retains the pinned, process-local offline
network-deny guard. The ordinary filter worker exits at idle and is included
while alive.
Every 2048×1536 Vox frame has PNG SHA-256
`52bb9be634a7a01d6e673509d53d6807bdcd90e3d0404164ae661fc6ba319322`.
Pixel equality refers to the previous Vox baseline, not to Chrome.

## Implementation and checks

The reductions preserve the HTML/CSS rendering path and normal interaction
state. They reduce common record sizes, share immutable values, avoid empty
optional state, and release retired document and paint graphs at ordinary idle.

- [Shared computed-property pages](../css/computed_property_store.v) (`ca92ef73`)
  use copy on write and transient
  exact-pointer interning. CSS checks pass in both GC modes and normal C-O2;
  eight layout functions pass in both modes. Ownership guards verify retired
  styles and images are not retained by the interner.
- [Optional grid metadata](../dom/document.v) (`0e2b4500`) reduces LayoutNode
  from 880 to 752 bytes;
  default reads and empty updates allocate nothing. Six functions pass in both
  GC modes, including live CSSOM and snapshot independence.
- [Lazy element interaction/HTML snapshots](../dom/element_interactive_data.v)
  (`722f9bcb`) reduce ordinary concrete
  element allocation buckets to 2,048 bytes. Both GC modes and normal C-O2 pass
  the selected checks: 100 invocations, 8,404 assertions, including ownership.
- [Compact selector variants](../css/simple_selector_storage.v) (`201f3f90`)
  reduce SimpleSelector from 496 to 176
  bytes. All 93 selected functions pass in each GC mode and normal C-O2. The
  ordinary Boehm result combines preserved 92+1 runs after correcting one
  assertion about a private tag; the original failed controller stays failed.
- Earlier committed changes compact computed caches, avoid empty pseudo state,
  replace retaining callback contexts, release paint scratch after drawing,
  and isolate the default filter engine in a worker that exits at idle. The
  worker's isolated browser RAM saving is not claimed separately.

C9 broad validation covered 797 unique functions per GC mode and 100 exact
upstream LibJS AST fixtures through an audited composite. Original failed
attempts and reviewed harness repairs remain preserved. This does not claim
all 797 ran again after the later features; broad flags omitted production
Skia text. The final **11 smoke cases and 8 mandatory SVG guards pass** through
the reviewed 6+13 composite described below. All eight SVG cases are pixel-exact;
the original fuzzy bounds and sparse platform allowances are unchanged. Canvas
text uses its existing sparse allowance: maximum channel error 8 and 577 pixels
above its base tolerance, within the unchanged limits of 41 and 1,700.

## Build and evidence

The measured production bundle is
`Build/wikipedia-nojs-ram-70/candidate-integrated-v13/source/Build/v/Vox.app`.
Its source commit is `a5c6fd2ba7e833d8c8ee68fe3adc51bd270ca730`, an isolated
C9-based integration of the 12 exact canonical patches listed in
`candidate-integrated-v13/integration-requirements.json`. It contains 6,280 Git
blobs plus the private build script. It excludes unrelated concurrent changes,
including selector borrowing commit `e289178a`, and is not byte-identical to
the current canonical HEAD. The feature commits themselves are in the canonical
repository.

The normal production build uses V's old compiler, Boehm and native Clang `-O2`,
without V `-prod`. Build, linked-library closure, signature, worker-input
preflight and headless startup all exit 0. Source/native/toolchain/runtime pins
remain unchanged. The executable SHA-256 is
`9925a47e76a1457ead9ada6fd6495db5d22505944d57eb0567add11feda87683`.
Private validation does not replace the concurrently owned canonical
`Build/v/Vox.app`.

Evidence is retained under `Build/wikipedia-nojs-ram-70/`:

- `final-five-paired-c13-v1/{manifest,result}.json` and `raw/`: all ten raw
  timelines, readiness/resource audits, process identities and five exact frames.
  The raw summary SHA-256 is
  `ddb60c910be3c34404afb67018e11c2a3ea63c4c54ada0138e986d273cb42058`.
- `candidate-integrated-v13/`: committed archive, source proof, generated C,
  compiler response, production logs and preflight/runtime receipts.
- `regression-integrated-c13-v2/` and `regression-integrated-c13-v3/`:
  guarded visual results and the final `composite-result.json`, SHA-256
  `d4771bd37029dc6939cf5fd3739bc80b17854a98ca6b940a67e78a9d6682dbf0`.
- `broad-integrated-v9-composite-result.json`, focused pager/grid/DOM receipts,
  and `simple-selector-compact-v1/handoff-final.json`: functional and ownership
  checks, including preserved failed controls and attempts.

C10 and C12 were valid setup-only checkpoints at 64.592% and 67.9066% less
settled RAM. C10's separately labeled normal-JS Chrome supplemental result reused
its Vox row and is not the final comparator. C11's GUI navigation failed because
the old executable lookup selected the injected offline-guard dylib as its
worker; it has no RAM credit. Kernel-path fix `0109242b` is included in valid
C12 and C13. All failed output remains retained; the final cohort contains five
fresh complete pairs without retries or excluded observations.

The first visual attempt, `regression-integrated-c13-v1/`, captured its first
frame but could not compile the comparator: inherited `VEXE` selected a newer,
incompatible V standard library. That attempt remains failed. The unchanged
comparator accepted the retained frame with the original bounds after setting
`VEXE` to the explicitly selected fallback compiler. This environment-only
correction is recorded in `regression-integrated-c13-env-recovery-v1/`, with
18,518 compiler/library/native/source/artifact pins unchanged. The browser,
capture policy and comparison tolerances were not changed.

The second visual controller stopped when the separately owned canonical app
changed during private capture. Its first six cases completed every guard; the
seventh pixel comparison passed but was excluded from accepted coverage because
the canonical-app guard then failed. All private-source/binary/provider pins
remained unchanged. The final visual result combines those six accepted cases
with 13 guarded passes from a fresh manifest. That continuation exits 0 and
retains the unchanged canonical-app guard. Together they cover the original 19
cases exactly once in accepted coverage. Both failed controllers remain failed;
no guard or tolerance is waived.
