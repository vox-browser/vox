# Maximized Retina Reddit image replay

Commit `7d26a9fa` transfers only visible image regions when replaying root raster
tiles. A newly exposed strip no longer requires allocating, clearing, comparing,
uploading and reading back every CPU pixel of the complete tile. The GPU surface
retains its original dimensions and image transform, preserving interpolation,
MSAA and fractional scrolling. The full-tile path remains available when the
optional native API is absent. Cache identity includes the view origin and full
surface extent, with owned source/backdrop comparisons and bounded storage.

The focused checks pass 1,920 exact GPU comparisons and 864 complete native canvas
comparisons. They cover cold/warm replay, 1×/2× density, fractional transforms and
scrolling, RGBA/YUV, source/background mutation, color profiles, clipping, MSAA,
padded/unaligned rows, isolated layers and invalid-input failure without changing
caller pixels. Reproduce against an independent reference app:

```sh
python3 tools/run_memory_bounded.py --report Build/image-regions-job.json --limit-gib 3 -- \
  sh tools/test_native_image_regions.sh REFERENCE_APP_MACOS_DIR CANDIDATE_GRAPHITE_DIR
```

The performance fixture is the cached
`https://old.reddit.com/r/UkraineRussiaReport/` page, with hidden bookmarks,
network access disabled and a fixed 600-wheel trace. Strict checks require equal
resources, wheel positions and per-frame command counts. The actual maximized
document is **1728×1001 CSS pixels at 2× backing scale**. An injected Cocoa
geometry probe sets the window to the selected display's visible frame before
the five-second settling period and records its 1728×1085 content bounds.
The toolbar and status bar account for the remaining 84 pixels. Merely requesting
a window height was insufficient: AppKit clamped the earlier runs to a
1728×969 document. Those receipts remain separate.

The control changes one export-trie byte to hide the optional region API; all
thirteen Mach-O text sections remain identical and actual dynamic lookup
verifies the fallback. Both execution orders are retained:

| Measurement | Control, first | Regions, second | Regions, first | Control, second |
| --- | ---: | ---: | ---: | ---: |
| Mean native completion cadence | 98.93 fps | 109.12 fps | 108.24 fps | 96.68 fps |
| Moving callback median | 2.487 ms | 2.514 ms | 2.578 ms | 2.352 ms |
| Moving callback p95 | 16.460 ms | 13.272 ms | 13.627 ms | 15.337 ms |
| Moving callback maximum | 83.166 ms | 34.890 ms | 31.262 ms | 82.931 ms |
| Moving retired instructions | 31.667 billion | 21.827 billion | 22.014 billion | 31.494 billion |

Each run includes all 600 callbacks and 599 completion intervals; instruction and
callback rows select the same 560 moving callbacks. The isolated instruction
reductions are 9,840,302,050 (31.07%) and 9,480,172,162 (30.10%), totaling
19,320,474,212 for this workload. Both medians increase slightly, while both
pairs improve tail latency and total callback work. After the first 60 callbacks,
the two optimized runs average 117.38 and 116.16 completed fps, with p95 callback
work of 4.108 and 4.184 ms. All remaining 540 callbacks in each run finish within
15.986 ms. Cold-frame stalls remain included in the table.

The verified signed production artifact averages 110.57 completed fps over all
600 callbacks, with moving-callback p95 of 14.571 ms and maximum of 44.402 ms.
After the first 60 callbacks it averages 117.85 completed fps; all remaining
callbacks finish within 15.040 ms. This artifact contains other shared changes,
so only the API-disabled comparisons above receive isolated performance credit.

Four complete document comparisons, after 30 and 45 wheel callbacks at both
1× and 2× raster scale, are byte-exact between control and candidate. Only these
pixel fixtures prepend a JavaScript `Date` override to the cached HTML, keeping
Reddit's time-ago labels deterministic. Native clocks and the timed fixtures
remain unchanged. The fixed fixture, original HTML hash and script are recorded
in `fixed-date-fixture.json`; no pixels are masked or tolerance bounds changed.

The broad native raster, glyph, shape-backdrop and tiled-image checks pass.
Production signature verification and headless startup pass. All eight required
SVG mutation comparisons are pixel-exact. All eleven smoke screenshots equal
the preceding production baseline: six compare exactly to their references,
canvas text passes its existing allowance, and four existing reference
mismatches remain (`inline-node`, `ordered-list`, `text-decorations` and
`default-ignorable-code-points-not-painted`).

Completion receipts include native publication, scheduling and log delivery
latency; they establish neither physical display scanout nor uninterrupted frame
delivery. The cached fixture measures rendering rather than changing live-site
network or script workloads. These results are independent of the earlier
[scroll damage measurements](OLD_REDDIT_SCROLLING.md).

Evidence is retained under `Build/urr-maximized-20261025/`:

- `maximized-performance-summary.json`, the four `maximized-*/summary.json`
  timing runs and each run's `actual-viewport-proof.json`.
- `maximized-pixels-*-equality.json`, `fixed-date-fixture.json` and the uncropped
  window captures plus document-only PNGs.
- `native-guard.json`, `setup-checks-guard.json`, `maximized-final-v2-guard.json`
  and `final-validation-summary.json`, with the native, smoke and SVG logs.
- `production-reused.json` and `production-identity.json`, pinning the successful
  serialized production build and copied signed application at
  `production/Vox.app`. Its relevant native inputs equal commit `7d26a9fa` before
  and after that build. The shared C++ changed during the build; the record does
  not claim complete source provenance for that file.
- `control-export-proof-v2.json`, `control-text-proof-v2.json`,
  `control-symbol-proof-v2.log` and `committed-image-region-proof.json`. The last
  pins seven complete files and the two committed C++ hunks without attributing
  concurrent C++ edits to this change.

Failed fixture attempts are retained without validation credit: the first
control preparation failed its export check; early captures used the clamped
window or changing time-ago labels; a clock-injection attempt loaded a
non-scrollable document; two queued launchers exited before starting their
children. A short setup-only run also faulted during network-thread shutdown.
The completed final batch uses neither the clock dylib nor failed timing runs.
