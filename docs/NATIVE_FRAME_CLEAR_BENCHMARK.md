# Parallel native document clears

Commit `041ff0527` divides large white bitmap fills across up to four
participants on macOS. Each participant gets whole rows with a target
minimum of 2 MiB of pixel data. The fill joins before Quartz draws into
the bitmap, and bytes in row padding stay untouched. Small fills use the
caller. The initial document clear and the full clear of GPU scroll-tile
input use the same helper. `VOX_SERIAL_FRAME_CLEAR=1` selects serial execution.

## Results

| Page | Median clear, serial | Median clear, parallel | Median launch to capture exit, serial | Median launch to capture exit, parallel | Clear pairs faster |
| --- | ---: | ---: | ---: | ---: | ---: |
| Hacker News | 1.233 ms | 0.524 ms | 1890.1 ms | 1927.5 ms | 7/7 |
| GitHub | 0.134 ms | 0.098 ms | 6230.5 ms | 6400.6 ms | 7/7 |
| Old Reddit | 0.127 ms | 0.305 ms | 1777.0 ms | 1796.6 ms | 6/7 |

Hacker News and GitHub median first clears took 57.5% and 27.4% less time.
GitHub also rendered a second eligible clear in every visit. The median
sum of its two clears fell from 1.045 to 0.694 ms. Old Reddit improved in
six pairs, while its independent medians regressed from 0.127 to 0.305 ms.
The serial Old Reddit range was 0.108–1.569 ms.
Launch-to-capture medians rose on all three pages. The difference between
paired page timings varied by more than the clear-time savings.

All 42 browsers and the memory guard exited zero. Sampled peak process-tree
RSS was 2,724,691,968 bytes on the 18-logical-CPU macOS 27.2 host. The
one-minute load at launch ranged from 10.29 to 20.64 while other sessions ran.
Every capture matches its separate serial reference byte for byte after
decoding the PNG. Served resource URL, method, status, and body-hash sets
were constant per site, with 6 Hacker News, 153 GitHub, and 18 Old Reddit
archived responses. The audits preserved 30 story IDs, 33 repository row
IDs, and 25 post IDs respectively. The GitHub README, latest-commit entry,
and file commit links matched across all visits. Each document reached
complete readiness at the requested scale with JavaScriptCore initialized
and zero native or JavaScript errors.

## Workload

The comparison uses seven alternating fresh-process pairs per archived page.
Hacker News is the homepage, GitHub is `github.com/vlang/v`, and Old Reddit is
`old.reddit.com/r/programming/`. Each browser uses JavaScriptCore, an empty
private profile and HTTP cache, and a 1024×768 document viewport at 2×.
The loopback replay serves the archived bodies at their original HTTPS origins
and denies other requests. OS filesystem and shader caches remain available.
The benchmark measures the first eligible 2048×1760 white fill and the elapsed
time from process launch through document PNG encoding, the audit, and process
exit, with a one-second screenshot settle period.

The published browser predates the change. Both arms use the same single-C,
literal `-prod` executable with the same diagnostic library loaded. The
library checks the actual Mach-O executable header and UUID
`EB00A1D4-5F67-3F81-BE35-502CE3A5EF7B`, then recognizes the return address
at image offset `0x1a4ac` from the packed white fill in
`native_draw_solid_rect_srgb`. It checks the fill value and byte count. The
control calls the original `memset`, and the candidate calls the exact
committed row-fill helper. The diagnostic brackets the initial fill in the
shared browser in both arms. Production-bundle validation of the commit
awaits its queued build.

## Focused checks

The native check passes 288 existing Quartz comparisons and two large
packed/padded-buffer comparisons in both modes. ThreadSanitizer passes the
native check. The native scroll-raster regression passes its exact-pixel
checks. The first browser pilot reaches the eligible clear on all three
pages. The first diagnostic pilot observes two eligible clears on GitHub,
so the cohort records all eligible clears and uses the first for the
stage comparison.

## Additional diagnostics

The first capture pilot stopped after a successful browser launch because the
driver lacked Pillow. The corrected pilot used ImageMagick to hash decoded
pixels and supplied the reference for each site. The first injected pilot
captured all three pages and exposed a driver assumption of exactly one clear
per visit. The timing cohort retained every eligible call after correcting
that assumption.

A follow-up probed bitmap page residency through `mincore`. The first probe
lost its captured caller address during stack setup and was rejected. With
the residency scan moved outside the interposed function, all Hacker News
and Old Reddit clears reported 880 of 880 pages resident, across both fast
and slow fills. GitHub could have a resident first fill and a nonresident
second fill. A separate 512 KiB prefix timing also saw a fast prefix before
a slow remainder. Both diagnostics lacked a reliable admission signal.

The existing production build failed its sealed-source membership check while
the checkout was changing. The commit hook recorded a coalesced build request
including the clear change. The benchmark exercised the initial clear routine
through the pinned preview while the managed production bundle remained older.

## Input identities

Published receipt `20261118-014520-e67f738d` and executable SHA-256
`23ba3183f6c6446597823e434ba9016fc6949940758a6bcbcba91991b782b3bb`.
The AVIF helper SHA-256 is
`ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`.
The adblock worker SHA-256 is
`162049e6fe2e964ac573fcc732bfdff86216368c8c3dac07417b9c8316a1dc3e`.
The diagnostic dylib SHA-256 is
`a995681251e105a827f341b383ce94d5eea1b4ccf66bd6e730b4d5fd2196df41`.

| Page | Archive manifest SHA-256 | Decoded 2048×1536 RGBA SHA-256 |
| --- | --- | --- |
| Hacker News | `e1425162ca7c3373275914a5e7373f4a6a240ae4ce05d3160cf7039371c63ce0` | `a12f1a485f6b1e6f9d87dc1a49e47c3e2b7c2245858332e1209ff15041734642` |
| GitHub | `893e042c4f31e1b7fb984c81cf8f6a2a7eb65d790f7c3f4cc3e372c065de302d` | `ff492e78c0ab8dff0430f7bf2d14d25e20b7f9c2966714a9ed39e06a7cd25e9d` |
| Old Reddit | `313886b3b917ef8c5475c5d0df04ce0d19461e4d097c6f70ac1fbd0395df2b13` | `d31ea76663720b84aa5e78a722e3cb21eb41cb345742572d2e6e66fc1070bc1a` |

## All timed pairs

Clears are exact nanoseconds, listed in execution order within each visit.
Odd pairs run serial first. Even pairs run parallel first.

| Page | Pair | Serial clears, ns | Parallel clears, ns | Serial launch to exit, ms | Parallel launch to exit, ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| Hacker News | 1 | 1894959 | 464625 | 2149.607250 | 2159.158667 |
| Hacker News | 2 | 1232958 | 798834 | 2059.380084 | 2195.115625 |
| Hacker News | 3 | 1307084 | 523750 | 1982.701042 | 1968.371875 |
| Hacker News | 4 | 1221500 | 534542 | 1890.054500 | 1927.479875 |
| Hacker News | 5 | 1096250 | 523917 | 1845.786625 | 1840.326375 |
| Hacker News | 6 | 1395750 | 517125 | 1887.693583 | 1847.487917 |
| Hacker News | 7 | 645000 | 448000 | 1843.243208 | 1889.240958 |
| GitHub | 1 | 159625, 1007500 | 102417, 737625 | 7402.507667 | 6374.037917 |
| GitHub | 2 | 134375, 1008250 | 97500, 596875 | 6230.498459 | 6679.942083 |
| GitHub | 3 | 210167, 1269875 | 99125, 597875 | 6694.067083 | 6865.090084 |
| GitHub | 4 | 120292, 839708 | 97166, 523792 | 6108.223875 | 6610.732416 |
| GitHub | 5 | 150875, 894042 | 102542, 799708 | 7020.002334 | 6400.575875 |
| GitHub | 6 | 120584, 855833 | 78833, 588333 | 5958.663208 | 6255.954667 |
| GitHub | 7 | 116000 | 83000, 543958 | 5874.744584 | 5963.690334 |
| Old Reddit | 1 | 127416 | 92125 | 1864.010291 | 1871.754125 |
| Old Reddit | 2 | 107709 | 73250 | 1759.155666 | 1796.636667 |
| Old Reddit | 3 | 111541 | 480000 | 1748.737958 | 1791.642625 |
| Old Reddit | 4 | 1569000 | 414917 | 1777.038750 | 1806.131666 |
| Old Reddit | 5 | 721375 | 456750 | 1780.317041 | 1778.451583 |
| Old Reddit | 6 | 849125 | 304708 | 1759.128083 | 1788.925333 |
| Old Reddit | 7 | 121583 | 84000 | 1855.709167 | 1849.725292 |
