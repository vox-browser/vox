# Ladybird newly imported tests 501–700

This batch continues the earlier 500 with the next **200 fixed test IDs** in
[the committed selection](../Tests/Browser/ladybird-new-501-700-20261109.txt).
They are discovery positions 501–700 newly imported between Ladybird
`963d46a829f3e1b79f44dba9d02afb70654300fa` and fetched revision
`2919bf87a5e5dfc49a210a70bda079afa411c6c5`. Selection uses offset 500 and limit
200 before execution, with no overlap with the earlier 500 or filtering on
browser results. The upstream working checkout remains unchanged.

**194/200 pages pass; six upstream blockers prevent 200/200 acceptance.**

## Fixed cohort and baseline

| Group | Pages |
|---|---:|
| css-grid | 109 |
| css-highlight-api | 19 |
| css-images | 1 |
| css-inline | 15 |
| css-lists | 4 |
| css-logical | 1 |
| css-masking | 8 |
| css-multicol | 9 |
| css-overflow | 7 |
| css-overscroll-behavior | 6 |
| css-position | 19 |
| css-properties-values-api | 2 |
| Total | 200 |

The existing shared production executable, SHA-256
`db8acd8538ffa9db2ed78617e018362d1b96c0150e1d0e6784b6f0bac2391337`, passes
50/200 pages in a complete run of this selection. Its build receipt requests
head `45375fcc55f6e885c9d4218fa926af1ccea1bf8d` and predates recent engine fixes.
It supplies baseline evidence only.

The current native baseline also passes 50/200 pages and 3,313/6,012 reported
assertions. Missing APIs abort registration on some pages, so 6,012 is the
observed baseline assertion count, not a final denominator. It reuses the
previous batch's sealed native executable, SHA-256
`e77c61dba584da41dffc190564de86d7afaa3691694798aff89b7bd1f1020c19`, with fresh
native navigation, DOM/CSS/layout, JavaScriptCore, HTML event loop and separate
profile per page at 800×600. It does not validate painting or the GUI.

Both complete baseline runs use original immutable fixtures through upstream
wptserve. The existing timeout normalization and collecting reporter preserve
assertions. All executable/controller/server and fixture checks stay pinned.
Failures, harness errors, timeouts and missing results remain failures.
Native pages use 2 GiB / 80 second guards; the outer 3 GiB guard completed
cleanly with 487,407,616 bytes peak RSS over 254.05 seconds.

## Latest complete native run

The final complete native run (27) passes **194/200 pages** and
**5,966/6,038 reported assertions**, up from the 50/200 baseline. All identified
engine failures in this selection are resolved. **200/200 acceptance remains
blocked by the six upstream cases below.** All 200 selected pages and their
original assertions remain in the run, including harness errors and failures.

This run uses the C `-O1` native executable SHA-256
`4d706cd6811207cb105374a29b605366630eea949639e11f6a1a04a7390979ad`.
It exercises native navigation, DOM/CSS/layout, JavaScriptCore and the HTML
event loop with a fresh profile for every page. It does not validate GUI or
painting behavior. The shared completed production bundle still predates these
fixes and supplies baseline evidence only; the managed production rebuild is
pending.

The outer 3 GiB guard completed in 186.70 seconds, with 525,664,256 bytes
sampled peak RSS. It exits 1 because the six upstream cases remain failures.
Executable, controller, server and fixture identities remained unchanged
throughout the run. Both grid-lanes track-animation pages pass all 726
assertions each under the unchanged harness timeout. The combined 18-file
focused selection also passes, including reversed writing modes, right-to-left
baselines, live select geometry, intrinsic percentages and scroll overflow.
Other sessions heavily loaded the shared 18-CPU host (observed load averages
exceeded 170 during this task); build elapsed times are not performance
measurements.

## Remaining upstream blockers

Four selected pages invoke functions missing from Ladybird's own pinned
`grid-definition/support/testing-utils.js`. They call
`TestingUtils.testGridTemplateColumns` or `TestingUtils.testGridTemplateRows`;
the imported file exports only `testGridTemplateColumnsRows` and
`testGridTemplateAreas`. These pages register no assertions:

| Page under `css/css-grid/grid-lanes/items/` | Result |
|---|---|
| `column-flex-track-intrinsic-sizes` | Missing helper; harness error |
| `row-flex-track-intrinsic-sizes` | Missing helper; harness error |
| `column-intrinsic-track-sizes` | Missing helper; no tests registered |
| `row-intrinsic-track-sizes` | Missing helper; no tests registered |

Two tentative pages under `css/css-grid/grid-definition/` require excluding
implicit tracks from resolved values, while their ordinary counterparts
require including those tracks for equivalent grid layouts:

- `grid-inline-template-columns-rows-resolved-values-001.tentative`
- `grid-template-columns-rows-resolved-values-001.tentative`

Vox and Brave 157 both pass 40/76 assertions on each tentative page, with the
same serialization conflicts. Both ordinary counterparts pass all 38
assertions. These competing requirements remain visible; no fixture or support
file was changed to turn them into passes.

## Retained evidence

Complete evidence through native run 5 is archived under
`~/.cache/vox/wpt/batch501-700-20261109/evidence-through-r5/`. Runs 6–10 and their
focused checks/build receipts are under `evidence-r6-r10/`; completed runs
12–19 are under `evidence-r12-r20/` in the same parent directory.

Runs 21–27 and the final focused checks/Volt build receipts are under
`~/.cache/vox/wpt/batch501-700-20261109/evidence-r21-r27/`. The final results are
in `batch501-700-native-r27-full/{summary,cases,identity}.json`; the sealed
executable is `completed-core/native-r27-tests`. Controllers are retained in
`controllers/`, and the final compile/run logs are in `logs/`. Paths recorded
inside receipts refer to their original temporary `Build/` locations.
Completed job outputs have been moved out of `Build/`.

## Provenance and reproduction

Fixtures are exported without changing the upstream checkout to
`~/.cache/vox/wpt/ladybird-imported-2919bf87a5e5dfc49a210a70bda079afa411c6c5/`.
The exact selected objects and source pin are in
`~/.cache/vox/wpt/batch501-700-20261109/selection.json` and `source.json`.
The committed selection contains 200 unique IDs; its SHA-256 is
`bfa864a1c7e3e31ad5dee457bea39f4504009f0e1d799ca5b441a4bee98878b2`.
The following command checks the shared production bundle; its result remains
baseline evidence until the managed rebuild includes the engine fixes.

```sh
python3 tools/run_memory_bounded.py --limit-gib 3 \
  --lock Build/UNIQUE.lock --report Build/UNIQUE-guard.json -- \
  python3 tools/wpt_compare.py --output Build/UNIQUE \
  --ladybird-ref 2919bf87a5e5dfc49a210a70bda079afa411c6c5 \
  --new-since 963d46a829f3e1b79f44dba9d02afb70654300fa \
  --offset 500 --limit 200 --browsers vox --chunk-size 10 \
  --width 800 --height 600 --browser-memory-gib 2 --require-all-pass \
  --wpt-server-root /Users/alex/code/3rd/web-platform-tests
```

Required Volt checks ran before the engine fix commits. The final `make app`
check (23) succeeds. The direct
`v -memory-limit 10G -enable-globals -o volt .` build reaches its configured
10 GiB compiler physical-footprint limit. That limit is preserved; the failure
and the successful app build are retained with the final evidence.
