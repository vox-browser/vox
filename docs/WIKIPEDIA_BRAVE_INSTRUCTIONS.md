# Wikipedia instructions against Brave, 2026-11-01

The existing production Vox build already meets the requested target of at least
10% fewer retired CPU instructions than Brave on this workload. Across seven
alternating fresh-process pairs, Vox's median is **6,600,176,026** instructions
and Brave's observed median is **9,661,801,676**: **31.69% fewer** by the ratio
of medians. Even the highest Vox sample is **30.41% below the lowest Brave
sample**. No runtime optimization was necessary or credited in this task.

This measures the **frozen `https://www.wikipedia.org/` portal, with author
JavaScript disabled in both browsers, from startup through document capture**.
Disabling scripts matches Vox's existing Wikipedia policy. It does not establish
performance with page JavaScript enabled or on Wikipedia article pages.

| Pair | Vox retired instructions | Brave observed retired instructions |
| --- | ---: | ---: |
| 1 | 6,691,451,984 | 9,710,599,960 |
| 2 | 6,577,144,024 | 9,640,662,194 |
| 3 | 6,621,690,083 | 9,667,137,419 |
| 4 | 6,599,490,566 | 9,645,106,149 |
| 5 | 6,600,176,026 | 9,678,681,815 |
| 6 | 6,597,124,643 | 9,661,801,676 |
| 7 | 6,608,682,416 | 9,614,970,248 |
| Median | **6,600,176,026** | **9,661,801,676** |

The median paired reduction is 31.58%; the ratio of arithmetic means gives
31.53%. The acceptance gate uses the more conservative maximum Vox count
against the minimum observed Brave count, requiring a ratio no greater than
0.90. The measured ratio is **0.695941**. Every attempt in this cohort is retained;
there were no retries or sample exclusions.

## Workload and counters

Both browsers receive the same original response bodies and headers from a
sealed, disk-only loopback proxy. All 15 archived responses have status 200.
The original scripts remain in the archive but do not execute. Both browsers
start with an empty private profile and cache for each sample; raster snapshot
reuse and ambient proxy, heap and scripting overrides are removed. Normal
browser filtering remains enabled. Missing responses are not forwarded to the
network. Vox additionally has the tested process-local network-deny library.
The document viewport is 1024×768 CSS pixels at screenshot scale 1.

The HTML is 122,421 bytes, SHA-256
`862d64aa9af12fdbaf360b5ceb01307b74f998f961edfd96ba30d8e358034037`.
The full archive fingerprint is
`a5bb19fc87b02e768b2d958af4b45c44571709be1f8d7105694dea6aef286f0b`.

Counters use `proc_pid_rusage/RUSAGE_INFO_V4/ri_instructions`, sampled every
5 ms, including all observed browser/helper tasks and charged kernel work.
Vox includes native capture, its content audit and teardown; both observed Vox
tasks have final exit readings in every sample. Brave ends at the last completed
sampling pass before its first screenshot response and excludes subsequent
content auditing and shutdown. Brave is a conservative polling lower bound:
short-lived unsampled children can be omitted, and its missing final-sample
counts are 3, 2, 2, 1, 3, 1, 1. No unreadable-counter errors occurred. GPU
execution, WindowServer and the observer/replay server are excluded. Native
instruction-checkpoint logging is included in Vox's counts. These are startup
and capture totals, not isolated parser/layout costs or displayed-frame timing.

The host has 18 logical CPUs. One-minute load averages during the cohort range
from 9.04 to 9.88, with independent work active. Each sample retains its start
timestamp and load averages. The bounded job completes with browser/observer
and guard exit zero in 14.57 seconds, with 1.23 GiB sampled peak aggregate RSS.
Elapsed time receives no separate performance claim.

## Rendering checks

All 14 captures match their respective fixed engine references exactly. Native
audits require the complete, fully active Wikipedia document at the requested
viewport with paint commands; Brave also retains its URL, title, text and image
audit. The browser-specific references themselves differ at **7 of 786,432
pixels**, confined to the search-box corners at x287–288, y470–513. No tolerance,
mask or altered reference is used. The benchmark passes instruction usage and
per-engine rendering stability; **cross-browser pixel equality remains unmet**.
The default shared-reference mode still rejects such a mismatch.

A separate live navigation using the same native measurement endpoint and
Vox's automatic script policy passes with a screenshot exactly matching the
frozen native reference. Its single diagnostic total is 6,731,014,703
instructions and receives no paired performance credit. An earlier live check
used a different delayed, document-only capture path; its complete document
loads successfully but differs at 78,191 pixels despite identical HTML bytes.
That result is retained separately and is not credited as pixel parity or
compared for instruction savings.

## Build identity and checks

The benchmark reuses the latest completed production bundle available for the
cohort, copied as build outputs into `measured/Vox.app` to keep its identity
stable while another session continues shared development. No source checkout
was copied and no production build was requested. The preceding baseline
diagnostic uses a separately retained older completed bundle and is not a
matched optimization control.

Measured executable SHA-256:
`9b4ad5481fd8f66d68ee6e4c4e5baf6285aab22de8b4e97b4649ddf09212e0e5`.
Brave's framework version is 156.1.98.60; CDP reports Chromium 156.0.8078.48.
The benchmark pins 54 inputs, including Vox's transitive non-system native
dependencies, helper/snapshot, Brave's launcher and dlopened framework, both
references, the pixel comparer, network guard and measurement sources. All pins
and the full archive fingerprint remain unchanged through the cohort. The
shared checkout has unrelated in-progress changes; these observations identify
the binaries and do not attribute savings to those changes.

The task fixes the archive tool's valueless `style` attribute crash, restores
the native network-guard test's expected completion marker, and adds sealed
replay, private environments, runtime pins, retained failure samples and explicit
per-engine reference support to the Wikipedia driver. Focused archive (7),
Wikipedia observer (5), process counter (15) and network-guard/replay (9) tests
pass. The expanded 88-case browser-observer run initially exposes the missing
network-test marker; its native assertions already pass. All nine tests in that
affected file pass after the marker fix. The original failed receipt remains.
No engine change or measured optimization delta triggers a broad translation
regression batch.

## Evidence and reproduction

All artifacts are in `Build/wikipedia-instructions-20261101/`:

- `paired/summary.json`, `paired/pair-*.json`, `paired/*.png` and
  `paired/replay/requests.jsonl`: every accepted measurement and response.
- `paired-guard.json`, `paired.stdout.log`: exact command and actual exit codes.
- `measured-identity.json`, `paired/input-sha256.json`,
  `compositor-gap-v9-production-guard.json`: build/runtime identity and the
  reused production-build receipt.
- `archive-v2/manifest.json`: sealed original responses and acquisition commands.
- `live-measured-endpoint/`: live default-policy validation at the measured
  capture endpoint. `live/` retains the different document-only capture.
- `archive-tests-guard.json`, `focused-observer-tests-guard.json`,
  `counter-tests-guard.json`, `network-guard-tests-guard.json`: focused checks.
- `archive-guard.json`, `archive-capture-guard.json`, `archive/`,
  `diagnostic-guard.json`, `diagnostic-replay/`, `observer-tests-guard.json`:
  the original CLI, archive-parser, proxy-connection and test-marker failures.
  The proxy diagnostic's DNS deny rule omitted the numeric loopback exclusion;
  it was interrupted after confirming an error page and earns no credit.

The retained cohort can be reproduced with a new output directory:

```sh
python3 tools/run_memory_bounded.py \
  --lock Build/wiki-repeat.lock --report Build/wiki-repeat-guard.json \
  -- python3 tools/wikipedia_browser_instructions.py \
  --archive Build/wikipedia-instructions-20261101/archive-v2 \
  --output Build/wiki-repeat \
  --expected Build/wikipedia-instructions-20261101/diagnostic-v2-brave.png \
  --expected-vox Build/wikipedia-instructions-20261101/diagnostic-v2-vox.png \
  --vox Build/wikipedia-instructions-20261101/measured/Vox.app/Contents/MacOS/Vox \
  --network-deny Build/wikipedia-instructions-20261101/network-deny.dylib \
  --diff-tool Build/wikipedia-instructions-20261101/pixel_diff \
  --repeat 7 --required-reduction 0.10
```

To freeze a new workload, run `python3 tools/page_archive.py capture
https://www.wikipedia.org/ --output NEW_ARCHIVE`. The driver's
`--capture-reference` and `--capture-vox-reference` modes capture independent
references from that archive. Omit `--expected-vox` to require shared-reference
cross-browser pixel equality as well as the instruction target.
