# Search results load latency

2026-10-18. Implementation: `ef75ad78`. This is one elapsed-time fix toward the
non-instruction-optimization ten-fix verification cadence. No retired-instruction
savings or Brave performance parity are claimed.

## Profile and change

The user's cached search document contains 25 results, 19 images, 10 stylesheets,
and seven external scripts. Initial native timing put image setup and scripting
at 3.3–7.6 seconds, while layout took approximately 120 ms. In a sampled run,
2,385 of 3,469 main-thread stacks were in `ImageHost` construction, predominantly
waiting for HTTP/TLS image requests. The phase called `run_javascript` includes
this native binding setup; these waits were not JavaScript execution.

Parallel preloading had already completed many of those image requests,
including unsuccessful thumbnail requests. Image binding setup discarded that
per-install response snapshot and retried failed requests synchronously.

The binding setup now consumes the current document's completed image preload
responses and failures. It retains the existing CORS restriction, rejects reuse
after adoption into another document, and avoids sharing stylesheet/script
responses with the image role. The response snapshot is released after initial
script setup so later author retries still use the normal fetch path. Sources
absent from the preload pass retain the existing fetch path.

## Matched measurements

The control and candidate were built from the same committed source baseline,
`36945e5a`, with only this image-fetch change added to the candidate. Five fresh
process pairs alternate execution order. Both render the same saved HTML with
scripting enabled, the same copied encoded-resource cache, the default collector
policy, and a 1024×768 native viewport. The endpoint is document installation
through the first submitted document frame. Main-document network time is
excluded. No saved raster replaces document rendering.

| Pair | Control first frame | Candidate first frame |
| --- | ---: | ---: |
| 1 | 4,721 ms | 1,603 ms |
| 2 | 4,814 ms | 1,472 ms |
| 3 | 4,323 ms | 1,361 ms |
| 4 | 5,582 ms | 1,684 ms |
| 5 | 6,023 ms | 1,798 ms |
| Median | 4,814 ms | 1,603 ms |

The measured median reduction is **66.7%**, approximately **3× faster**. All five
paired document captures have exact RGBA equality: zero differing pixels out of
786,432, with no tolerance change.

Warm isolated Brave produced first-contentful-paint readings of 64, 64, and
56 ms for the same saved HTML. This remains a useful reference, rather than an
equivalent endpoint: Brave's warm-process FCP can precede completed image loading,
whereas the native measurements include a fresh process's document installation
and first complete submitted frame. Native resource barriers and uncached image
requests still leave performance work. A separate command-line live request
returned HTTP 403, so these results do not establish live Reddit network latency.

## Validation and artifacts

- Four new focused cases pass with default GC and `-gc none`: failed preloads
  plus subsequent retries, redirected image bytes plus source changes, CORS
  rejection, and adoption into another document.
- Existing remote-image/CORS, initial-resource, and image-frame test files pass.
- `svg-image-source-switch-same-size` remains pixel-exact.
- Both isolated production builds and the standard production build succeed.
  The updated standard bundle passes signature verification and headless startup.

Private HTML, screenshots, the sampling profile, source/binary identities,
per-run logs, and measurement scripts remain in mode-0700 ignored
`Build/search-load-profiling/`. The principal receipts are `paired-latency.json`,
`pair-*.pixels.json`, `brave-latency.json`, and the focused/build logs. Account
content and search terms are excluded from committed fixtures and this report.
