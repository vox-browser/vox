# Lobsters homepage instructions

On 2026-11-02, seven alternating fresh-process pairs use a median of
**8,082,180,934 retired CPU instructions in Vox** and **27,446,683,211 in
Brave**, or **70.55% fewer**. The highest Vox count is **69.28% below the
lowest Brave lower reading**, passing the requested 10% gate. The existing
completed production build already meets the target; no engine optimization
or new engine savings are credited.

This result covers **browser launch through encoded document PNG availability**
on the dated frozen guest homepage at `https://lobste.rs/`, with full uBlock
Origin filtering. It includes browser, filtering and window/target startup.
It does not establish live author-script performance, isolated rendering time,
or scrolling FPS.

| Pair | Vox instructions | Brave lower reading | Brave upper reading |
| --- | ---: | ---: | ---: |
| 1 | 8,133,108,468 | 27,536,169,354 | 27,537,248,326 |
| 2 | 8,068,225,455 | 28,112,384,678 | 28,132,959,036 |
| 3 | 8,080,934,925 | 27,035,490,458 | 27,046,440,044 |
| 4 | 8,082,264,207 | 27,446,683,211 | 27,491,340,393 |
| 5 | 8,110,498,502 | 27,388,674,672 | 27,392,347,694 |
| 6 | 8,082,180,934 | 27,448,348,012 | 27,479,721,335 |
| 7 | 8,074,478,451 | 26,474,632,462 | 26,504,046,018 |

All **14 captures match the unchanged live Brave reference at every one of
786,432 pixels**. Every capture verifies the complete title, URL, readiness,
viewport, all **25 ordered story IDs and short IDs**, story titles and link
destinations, and all **25 image sources and srcsets**. All 12 visible avatars
are decoded. All browser, benchmark and memory-guard exits are zero. Every
attempt is retained, with no outlier exclusions or retries within the cohort.

The conservative ratio is **0.307203829**. Exact integer acceptance is
`81,331,084,680 <= 238,271,692,158`, representing
`10 * max(Vox upper) <= 9 * min(Brave lower)`.

## Workload and filtering

The source is the existing [Lobsters guest fixture](../Tests/Browser/Brave/sites/lobsters/manifest.json),
whose [pixel audit](benchmark-results/lobsters-brave-pixels-2026-11-02.json)
establishes its complete-cache rendering policy. Its manifest SHA-256 is
`756d0a512540ea5e85f92308200fff39063cb623b740112f6229ca62189ed6ed`.
The 56,819-byte HTML has SHA-256
`00172b93b81ad8e789914d48cd659a869caf775d7466ce9f7325ce9b1d16f0f4`.
All **33 archived responses**, the capture provenance, the original PNG and
measurement sources remain pinned. The reference SHA-256 is
`8d6618c696e5c61a51f285ec00fcc801d5c21a4806c1acb50ae1d31c41c398c0`.
No reference, tolerance or content is changed to meet the instruction gate.

Both engines use the same frozen DOM, with author script elements removed,
normal scripting policy and uBO scriptlets retained. They replay original HTTPS
origins through one private SOCKS/TLS server with no live forwarding. Each trial
uses a fresh process and independent copies of closed encoded-resource caches:
Vox's existing warmed resource cache and Brave's existing warmed full-uBO
profile. Vox's settings profile starts empty; Brave's copied profile disables
Shields, retains the repository-selected lists and empty user filters, and has
automatic updates disabled. No decoded page raster is supplied. OS filesystem
and shader caches are retained. Ambient proxy and measurement controls are removed.

The document viewport is **1024×768 CSS pixels at scale 1**, with **five seconds
settling**. Vox uses an inactive native window on the display away from the
pointer; Brave uses its headless target with an emulated viewport. The native
traffic log is independently compared with full uBO for every Vox capture,
after its measured endpoint. Brave verifies extension readiness, selected lists,
disabled automatic updates and empty user filters before navigation. Browser,
extension, template, native-library, resource and reference hashes are checked
after every trial.

## Counters and browser identity

Both browsers use macOS resource-coalition cumulative retired-instruction
counters from exclusive coalition creation. These include **exited helpers**
and explicitly allowed coalition-owned Metal compiler and CascadeSets services.
Every Vox capture has a stable live ownership scan matching its native PNG
endpoint's task totals. Brave's CDP task inventory must fit the exclusive
coalition, with exact live membership before and after capture. Fresh roots
are distinguished from existing user browser processes, which remain outside
the measured coalitions.

Vox ends at the encoder-return marker, before writing the PNG. Brave ends at
completed CDP screenshot delivery, including base64/IPC overhead; the recorded
interval brackets that endpoint. Readiness polling and settlement are included.
Semantic audits, native filter verification and teardown follow the endpoint.
GPU execution, the observer/replay and services outside the exclusive coalition
are excluded. These are full startup/capture workflows with documented endpoint
differences, rather than identical internal rendering operations.

The existing canonical `Build/v/Vox.app` is reused directly, while another
production build is running. No bundle or source tree is copied and no new build
is requested. Its executable SHA-256 is
`e9b1cdeb2197ef69aacf701bb0e12149aecfabed3f2c68cb675d34631c3f681e`;
the successful production receipt records source HEAD `d8714ad8c4f6efb15c165bae94f632f7f89eeafa`
with dirty inputs. This identifies the measured completed bundle, not subsequent
source edits. Brave is **156.1.98.60**, with full uBO **1.75.0**. The durable
receipt retains native dependencies, browser/framework and measurement hashes.

The host has **18 logical CPUs** and one-minute loads of **5.34–6.68** during
the final cohort, with independent production compilation and other sessions
active. The adoption-aware 12 GiB guard observes **2,449.17 MiB** peak aggregate
RSS over **121.26 seconds**, adopts both browsers and helpers, and reports no
adoption error. No elapsed-time optimization is attributed to these results.

## JavaScript activity and retained attempts

A separate diagnostic explicitly selects JavaScriptCore, confirms
`enabled=true runtime=true sources=0 source_bytes=0 preloaded_scripts=0`, and
observes **one JSC context, one group and 161 evaluations in the Vox root**.
This workload runs browser bootstrap and filtering scriptlets, with no retained
Lobsters author script sources. The probe's positive startup-smoke control
records **three contexts and 462 evaluations**, with exit zero. The diagnostic
also matches the original pixels and complete story inventory. Injected probe
and timing runs supply no instruction acceptance samples or engine speed claim.
Brave selects V8 and executes the extension and CDP readiness/audit expressions.

Two initial diagnostics stop at Brave's automatic-update configuration gate;
they remain recorded. A subsequent Brave-only diagnostic passes. The first
seven-pair cohort passes the numeric and pixel gates but lacks ownership scans
matching Vox's final helper task totals. It receives **no final acceptance
credit**, despite its original harness summary. The independent ownership
assessment preserves that finding. Tooling commit `b17640f42` enables the
endpoint audit and makes it mandatory for acceptance; the final seven-pair
cohort above passes it. The original counts and failed setup attempts are
retained, and the repeated protocol earns no engine optimization credit.

## Evidence and reproduction

The [durable receipt](benchmark-results/lobsters-home-instructions-2026-11-02.json)
retains all final counts and bounds, prior attempts, identities, timestamps,
host conditions, audits and raw artifact hashes. Commands, logs, PNGs, semantic
and filtering audits, coalition snapshots, PID registries and actual exits are
under `Build/lobsters-home-instructions-20261102-102016/`. All **198 focused
benchmark tests pass**. No engine savings advance the broad-test cadence.
Tooling is committed in `861f58bc9` and `b17640f42`.

Repeat with new output, receipt, lock and registry names:

```sh
env -u ALL_PROXY -u HTTP_PROXY -u HTTPS_PROXY \
    -u all_proxy -u http_proxy -u https_proxy \
  python3 tools/run_memory_bounded.py \
    --lock Build/lobsters-UNIQUE.lock --report Build/lobsters-UNIQUE-guard.json \
    --adopt-pids-from Build/lobsters-UNIQUE-pids.json -- \
  python3 tools/lobsters_browser_instructions.py \
    --output Build/lobsters-UNIQUE \
    --memory-guard-registry Build/lobsters-UNIQUE-pids.json \
    --brave-profile-template Build/lobsters-home-instructions-20261102-102016/brave-template-final \
    --vox-cache-template Build/lobsters-parity-20261102-resume/automatic-complete/lobsters/vox-cache \
    --extension Build/forum-news-parity-20261030/extension/uBlock0.chromium \
    --checker Build/forum-news-parity-resume-20261030/adblock-check \
    --expected Tests/Browser/Brave/sites/lobsters/live.png \
    --diff-tool Build/hn-home-instructions-20261031/pixel_diff --repeat 7
```
