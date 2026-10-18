# Native search image loading

2026-10-18. Implementation: `5b91e681`. This is an elapsed-time optimization,
not an instruction-count claim. Broad regression credit is not inferred from
focused checks; this is one completed fix in the search-performance work.

Script-enabled native navigation now commits after styles and scripts are ready.
Thumbnails complete through a bounded eight-request loader on later event-loop
turns. Coalesced requests retain source-document identity, image-role filtering,
CORS state, adblock response checks, load-event delays, and stale-completion
suppression. Cached decoded images still provide natural dimensions before the
first layout. `img.complete` reads the live native model rather than a bootstrap
snapshot. Navigation cancels the previous loader.

A frozen control and candidate share baseline `17328490` plus cache-header fix
`8d0bd2c5`. The candidate adds this image change only. Five fresh-process pairs
alternate order and render the same saved search HTML with the same encoded
resource cache, scripting, default collector, and 1024×768 viewport. The endpoint
is navigation to the first submitted document frame, excluding main-document
network time. No saved raster replaces rendering.

| Pair | Control | Candidate |
| --- | ---: | ---: |
| 1 | 5,184 ms | 2,204 ms |
| 2 | 3,323 ms | 3,370 ms |
| 3 | 2,506 ms | 1,212 ms |
| 4 | 4,270 ms | 1,327 ms |
| 5 | 9,165 ms | 1,629 ms |
| Median | 4,270 ms | 1,629 ms |

The median fell 61.9%; four of five pairs improved. All five paired document
captures match exactly, with zero differing pixels. Host contention contributes
to the spread; this series does not establish Brave parity. An earlier complete
series also improved (1,966 to 1,014 ms median); the table above uses the final
image-role policy. Interrupted runs and the original cache-decoder panic are
retained without successful-run credit.

Twenty-five focused cases pass in both default GC and no-GC configurations:
nineteen native bridge/cache/form cases and six HTML asynchronous-image cases.
They cover gated slow thumbnails, first-layout cached dimensions, navigation-away
completion, request-role isolation, stale sources, failure/retry/removal, opaque
CORS state, adoption and returning to a decoded source. The canonical
`svg-image-source-switch-same-size` comparison is pixel-exact. The standard
production build succeeds, passes signature verification and headless startup,
and contains the new loader entry points.

Private captures, timings, source/binary identities and complete logs remain in
mode-0700 ignored `Build/search-speed/`. Principal receipts are
`policy-paired-latency.json`, `policy-pixels.json`, `source-manifest.json`,
`focused-policy{,-none}.{log,status}`, `html-4.{log,status}`,
`svg-guard.{log,status}`, and `production.{log,status}`. Search terms, cookies and
account content are excluded from this report and committed fixtures.

Later live testing established that authenticated windowed Brave and native
HTTP/2 navigation both succeed. Earlier HTTP/1 or headless failures are not a
basis for declaring live comparison blocked. Subsequent warm-window work uses
actual navigation and is reported separately.
