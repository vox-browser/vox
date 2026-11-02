# Old Reddit instruction recheck, 2026-11-03

The latest completed production bundle already passes the requested 10% gate
against Brave on the existing frozen `/r/programming/` workload. Seven complete
alternating fresh-process pairs give a Vox median of **3,953,436,832 observed
retired instructions** and a Brave median of **9,327,192,427**, a **57.61%**
reduction by the ratio of medians. The highest Vox observation is **56.19%**
below the lowest Brave observation. This verifies the existing bundle; no new
engine optimization or reduction against a matched Vox control is credited.

All 14 captures match the unchanged shared Brave reference at every one of the
786,432 pixels. Complete document audits retain all 25 post IDs in source order,
the `programming` title, complete readiness and the 1024×768 viewport. No
reference, tolerance or content policy changed. The earlier
[46.43% cohort](OLD_REDDIT_PROGRAMMING_INSTRUCTIONS.md) and the initial diagnostic
pair remain retained.

| Pair | Vox observed instructions | Brave observed instructions | Differing pixels, Vox / Brave |
| --- | ---: | ---: | ---: |
| 1 | 4,039,994,814 | 9,444,806,396 | 0 / 0 |
| 2 | 3,971,856,789 | 9,398,185,734 | 0 / 0 |
| 3 | 3,952,579,581 | 9,223,548,243 | 0 / 0 |
| 4 | 3,942,348,450 | 9,327,192,427 | 0 / 0 |
| 5 | 3,969,331,945 | 9,335,636,940 | 0 / 0 |
| 6 | 3,934,559,447 | 9,225,743,442 | 0 / 0 |
| 7 | 3,953,436,832 | 9,222,168,841 | 0 / 0 |

The observed-count integer gate passes:
`10 * 4,039,994,814 <= 9 * 9,222,168,841`.
Every browser, benchmark and guard exits successfully. No attempt was retried or
excluded. The separate initial diagnostic records 3,980,059,518 versus
9,301,952,103 instructions, with exact pixels in both engines.

## Scope and limitations

Counters use `proc_pid_rusage/RUSAGE_INFO_V4/ri_instructions` for both browsers,
sampled every 5 ms from fresh process creation. Vox includes startup, native
window setup, capture encoding, the document audit and teardown, reading its
root while it is an unreaped zombie. Headless Brave includes startup and blank
target setup through the last sampler pass before its PNG CDP response; its
subsequent document audit and shutdown are excluded. Navigation deltas are
supplementary. GPU execution and outside services are excluded.

Both process-tree sums are polling lower bounds. Vox's missing-final-sample
counts are 0, 0, 1, 0, 1, 0, 1; Brave's are 1, 3, 3, 4, 2, 3, 3. No counter
reads are denied. The gate compares observed counts and supplies no upper-bound
certificate. Direct subprocess launches retain their ownership under the memory
guard without LaunchServices reparenting. The 12 GiB guard records a peak
aggregate RSS of 1,383,137,280 bytes. The host has 18 logical CPUs and concurrent
compilation; recorded one-minute loads span approximately 9.16–9.56. These
observations establish no elapsed rendering-time or scrolling-FPS improvement.

The unchanged fixture removes executable author scripts, retains normal
scripting policy for `noscript`, and uses the same sealed encoded-resource
archive for both engines. Each observation uses a fresh private profile/cache,
capture scale 1, and the harness's unchanged settle policy. Operating-system
filesystem and shader caches remain warm. Fixture SHA-256 is
`a432e6846a949c02957b4e880300e588c1e0b4829276daee44d4c9ae100a7e90`.

Vox explicitly selects JavaScriptCore and Brave uses V8. A separate diagnostic
on the measured executable reports `enabled=true runtime=false sources=0` and
observes zero JSC context creations/evaluations in the actual root PID. The same
probe's headless smoke control creates three contexts and evaluates 462 scripts.
This script-free workload measures startup/rendering, without selected
page-script runtime execution. A fresh direct request to live
`https://old.reddit.com/` returns **HTTP 403** and no posts, so live rendering,
authentication and interaction acceptance remain unavailable.

## Identity and reproduction

The executable is the canonical `Build/v/Vox.app/Contents/MacOS/Vox`, SHA-256
`0bb14e2f940d1ee83a4a57f48179ab40fb3ecf71aa8b7331f199676792ab6974`.
Brave reports Chromium `156.0.8078.48`; its signed framework is
`156.1.98.60`. Executable, native-library, adblock worker/snapshot, harness,
fixture, archive and reference hashes remain pinned throughout the cohort.
This bundle predates the tab-coloring feature developed in the same session;
its performance result does not validate that feature.

[Durable raw counts and receipts](benchmark-results/old-reddit-programming-recheck-2026-11-03.json)
retain all per-process counts, identities, endpoints, exits, coverage omissions,
host observations and artifact hashes without storing the account-bearing page.
Full local commands, logs, audits and PNGs are under
`Build/reddit-tab-color-acceptance-20261103/`. Reproduce with a unique output:

```sh
env -u ALL_PROXY -u HTTP_PROXY -u HTTPS_PROXY \
    -u all_proxy -u http_proxy -u https_proxy \
  python3 tools/run_memory_bounded.py \
    --lock Build/reddit-recheck-UNIQUE.lock \
    --report Build/reddit-recheck-UNIQUE-guard.json -- \
  python3 tools/reddit_browser_instructions.py \
    --html Build/old-reddit-instructions-20261101/frozen.html \
    --expected Build/old-reddit-instructions-20261101/diagnostic/brave.png \
    --cache Build/old-reddit-instructions-20261101/frozen-cache \
    --output Build/reddit-recheck-UNIQUE \
    --network-deny Build/wikipedia-instructions-20261101/network-deny.dylib \
    --diff-tool Build/wikipedia-instructions-20261101/pixel_diff \
    --repeat 7 --required-reduction .10
```

No measured engine change advances the 5,000,000-instruction broad-test ledger.
