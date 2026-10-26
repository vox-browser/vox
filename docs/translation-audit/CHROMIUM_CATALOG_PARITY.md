# 4chan catalog comparison

Pixel-perfect parity for `https://boards.4chan.org/pol/catalog` remains open.
The retained run in `Build/4chan-catalog-20261027-label-2/` compared fresh
processes at a 1024×768 document viewport and native scale 2 against Brave
156.1.98.60 (Chromium 156.0.8078.48).

The executable SHA256 was
`a1167c7abc73b8b0ac45f1d3eb0f5ace4f1b44375df75dff3108af46f0de2123`.
`device-live-run.json` records its native-library hashes, fresh PID 22880,
exit code 0, and unchanged executable/library identity. Live navigation
reached the requested catalog with its expected title, complete readiness,
over 100 threads and decoded thumbnails. This establishes live document
loading, not live screenshot parity.

## Executed pixel results

| Comparison | Differing pixels | Total pixels |
| --- | ---: | ---: |
| Initial catalog, logical pixels | 2,604 | 786,432 |
| Initial catalog, native pixels | 6,525 | 3,145,728 |
| Select fixture, native pixels | 0 | 1,920,000 |
| Precision fixture, native pixels | 0 | 1,920,000 |
| Teaser fixture, native pixels | 0 | 1,920,000 |
| Transformed shadow fixture, native pixels | 19,277 | 1,920,000 |
| Catalog scrolled to 768 CSS pixels | 476,731 | 3,145,728 |
| Catalog scrolled to 1536 CSS pixels | 706,206 | 3,145,728 |

`strict-pixel-acceptance.json` reports **false** and retains all 25 comparisons.
`scroll-coverage.json` establishes complete coverage of the 14,457-pixel
document through 19 viewport offsets, ending at 13,689. No nonzero result was
accepted as pixel exact.

The replay freezes animated GIFs and hides `.danbo-slot` in both browsers to
match Vox's enabled EasyList policy. An unfiltered Brave capture includes a
728×90 advertisement slot and different vertical positions. These controlled
replay results cannot establish parity with an unmodified live Brave page.

## Remaining causes and validation

The propagated body's `background-attachment:scroll` image remains at the top
of Vox's viewport after scrolling. At the top-left pixel, both browsers
initially paint RGB `(254,214,175)`; after scrolling Brave paints the canvas
color `(255,255,238)` while Vox retains the fade. A pending fix gives scrolling
canvas image layers the root scroll context while preserving the stationary
canvas color and fixed layers. Its focused test covers root/body propagation,
horizontal and vertical scrolling, local/fixed attachments, and retained
command reuse.

`shadow-region-analysis.json` records exact normal, rounded and offset shadow
regions, with 952 differing pixels for the half-scale shadow, 17,364 for the
double-scale shadow and 961 for the rotated shadow. Most scaled-edge errors
are one blue-channel unit. This is diagnostic evidence, not a confirmed
compositing fix. The new bundle also needs to exercise the one-CSS-pixel
opaque-shadow cutout at device layout scale.

An option-label mutation regression, fractional shadow-color transport,
device-scaled shadow cutouts, and scrolling canvas backgrounds still require
their queued focused execution. The previous focused retry timed out during
compilation and supplies no executed-test credit. Four native cache tests
passed, but do not substitute for the pending layout and browser checks.

`Build/4chan-catalog-20261027-background-1/` contains the next frozen-source
pipeline: focused tests, native cache tests, one necessary production build,
startup smoke, fresh native captures, full scroll coverage and strict pixel
acceptance. The available production bundle lacks the option mutation hook,
device-scaled cutout and canvas scroll change, so it cannot validate them.
