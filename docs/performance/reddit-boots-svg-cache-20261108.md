# Reddit scrolling: published readback and SVG cache lifetime

The 60 Hz goal without stalls remains open. The installed readback fix is
validated, while the optional SVG-cache timing cohort is mixed and receives
no optimization credit. Reddit's default cache policy is unchanged.

Implementation commits:

- `f5d690561`: a callback that purges or replaces its renderer cannot repopulate
  the invalidated SVG raster cache with retired pixels.
- `37da4ce1f`: opt-in cache diagnostics report clips, gradients and segment counts.

Optimized and ASan/UBSan checks pass, including two reentrant invalidation
regressions and 72 real GPU stroke scenes per mode. Both offset 0 and offset 850
match the unchanged page references exactly with reuse disabled and enabled.
The first fixture compile fails because a capturing lambda does not satisfy
the nullable callback API; it receives no test-execution credit. A candidate
compile exits zero but is rejected after an unrelated all-header pin changes.
The accepted component verifies 199 actual compiler dependencies/static
libraries and matching before/after dependency lists.

The two control trials are fresh pure installed-browser validations, containing
`ee53a2fb4` and the earlier GG shape-cache fix. Fresh headless startup, JavaScript
and wheel-routing smoke also passes. The new cache-lifetime fix executes in the
focused checks and private-component pixel checks; its installed-bundle
validation remains pending behind the busy shared production worker.

## Protocol and identities

- URL: the user's Old Reddit DotA2 boots thread.
- Viewport: 1400×900 document, 112 chrome, 2× backing, 125% zoom.
- Inputs: 5,400 precise native wheels, nominal 120 Hz, delta 3, reverse every 300.
- Readiness: matching title, then 12-second settle; automatic scripts.
- Each process: fresh private profile/cache; OS caches retained; live SOCKS5h.
- Fixed-pose pixels: original-origin 152-response replay, external networking
  denied, scripts disabled, unchanged references/tolerances.
- Endpoint: completed native frame installation, not physical scanout.
  Throughput uses the full first-to-last input period.
- Actual C mode: single C unit, C `-O3`, V `-prod=false`, GG, JavaScriptCore.
- Timing candidate changes only `VOX_SMALL_SVG_PATH_CACHE=1`; both timing arms
  use installed components without renderer overrides or profiling.

Executable SHA256: `f26b41bdc7345c07673f9bbe6eeb9cda4308454efe8cb6a185537cc420f19d48`.

Installed primary SHA256: `c2ec42c024d74b3c447599cca8df48bb8e877594ba81e8c82fce8b457737b921`.

Installed Metal SHA256: `bce89e00ebfe0c7d3a6ee4ba70206ab17b987a50f3ac0cf3458d828d2f373eb9`.

Accepted private primary SHA256: `bd656886c746681424e7f06ff9474730ad7b89cd5998bca3c687fdbaf342a891`.

## Results

| Trial | Moving publications/s | Median ms | p95 ms | Maximum ms | Over 16.67 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| live-cohort/1-live-control | 113.535 | 8.409 | 12.403 | 42.480 | 1.288% |
| live-cohort/2-live-candidate | 102.276 | 8.979 | 16.016 | 56.940 | 4.023% |
| live-cohort/3-live-control | 95.957 | 9.587 | 17.069 | 43.428 | 5.573% |
| live-cohort/4-live-candidate | 104.432 | 8.840 | 15.306 | 39.333 | 3.330% |

Host load averages range from about 14 to 158 on 18 CPUs. One candidate
regresses and the next improves. All attempts remain retained; no isolated
gain or instruction savings are accepted. The short diagnostic observes
14 hits in 42 input calls, without clipping/gradient eligibility failures.
Its timings receive no performance credit.

The separate installed-default 5,400-input profile records 88 samples over
124 slow frames, with no dropped samples or failures. It observes GG reads/
uploads, Graphite submit/readback waits, event-loop servicing and copies.
Counts overlap and do not represent time fractions or identify one cause for
every missed deadline.

Full counts, boundary gaps and interpretation are in
[the scrolling report](../DOTA2_SCROLLING.md#2026-11-08-published-readback-validation-and-svg-cache-lifetime).

## Local evidence manifest

- Raw archive: `/tmp/vox-reddit-svg-waits-20261108.tar.gz`; SHA256 `ff70df5cb180534004d1651a887e6645cf48ed0705214c9f4e24349b4046bd53`; 31,656,030 bytes.
- Per-file hashes: `/tmp/vox-reddit-svg-waits-20261108-files.json`; SHA256 `856a299a382f02b72b583c1f6b68861facb93f7f8f210773ecfd367209aec554`; 531,989 bytes.
- Archive supervisor: `/tmp/vox-reddit-svg-waits-20261108-guard.json`; SHA256 `11a52a5683c62ce89f3481f4f30cb3afa0d7c019e43c8cf8af43df929f8918d7`; 362 bytes.
- Full structured receipt: `/tmp/vox-reddit-svg-waits-20261108-report.json`; SHA256 `166201af70aab6523fa22ea7d5838e6080418c854c38be2fb82a9d4dbe15c321`; 121,787 bytes.

The mode-0600 archive has 2,134 individually read-back and verified files.
Completed per-job Build output, locks/reports and temporary drivers are removed.
Raw JSON receipts stay local under the repository ignore policy.
