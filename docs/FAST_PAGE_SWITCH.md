# Experimental fast website page switching

Enable **Settings → Experimental → Fast website page switching** on macOS.
The preference is off by default and persists independently of proxy settings.

The built-in registry starts with HTTPS `old.reddit.com/r/<community>/` listing
sorts: hot, new, rising, top and controversial. A switch must stay in the same
community, at scroll position zero and 100% zoom. Query strings, fragments,
comments, other hosts and unsupported rendering use normal replay.

Navigation still fetches and installs the replacement document, runs its scripts,
resolves styles and performs layout. Before retiring the old document, Vox saves
owned signatures for its visible paint commands in 128 CSS-pixel tiles. It
compares these with the replacement paint commands in draw order. Only tiles
with equal, supported paint inputs retain their pixels. A changed selected tab
is repainted along with changed posts; the sidebar is retained only where its
paint inputs actually match.

The signatures include geometry, transforms, colors, clips, glyph indices and
positions, and concrete system-font identity. Images, effects, text without
retained glyphs, document fonts and unsupported payloads conservatively dirty
their intersecting tiles. Native reuse additionally
requires the old document/revision, viewport geometry, scale and raster format to
match the existing bounded scroll cache. Failed checks fall back to full replay.
The feature shares that cache rather than allocating a second document raster.

This first version saves native paint/replay work; it does not avoid fetching,
parsing or layout. It is not a DOM replacement algorithm or a promise that every
site or navigation will load faster.

## Measurement

`tools/measure_page_switch.py` submits the destination through the native address
control and records two latencies after `updateLayer` finishes: the first changed
Cocoa layer publication with the destination title (`navigation_ms`), and the
last changed document publication followed by two seconds of unchanged document
pixels (`settled_navigation_ms`). The quiet delay is excluded from that latency;
`--quiet-seconds` controls the observation window. The second endpoint includes
late images observed during the window, but neither endpoint establishes network
idle or physical display scanout. A later update outside the window remains
possible. Chrome-only updates do not extend the settled latency.

The tool captures the source, first destination, last changed destination and
end-of-observation frames, records executable/native-library/probe hashes, cache and
profile policy, viewport/backing scale, host load, timestamps and browser exit.
Run it under `tools/run_memory_bounded.py`, in alternating matched off/on trials.
Use `--diagnostic` in a separate trial to verify `VOX_PAGE_SWITCH reused=true`;
do not credit timings to a path that did not execute. Compare document captures
between modes, and retain failed runs as well as successful ones. Require the
last changed destination pixels to match the end-of-observation capture and the
control. Record first-versus-settled pixel differences separately; a title change
alone cannot establish that images finished rendering.

Live unauthenticated access to the screenshot's subreddit redirected `/new/` to
login on 2026-10-26; the configured external proxy returned HTTP 403. A direct
retry on 2026-10-27 again reached the login redirect and ended in HTTP 403
(`Build/page-switch-20261026/live-access-20261027/result.json`). The local
comparison therefore uses an archived hot response and a **derived fixture**
that reverses its posts, changes the selected tab and changes the document title.
It is not an archived or live response from Reddit's `/new/` endpoint.

## Local page copy

The saved pages and assets are packaged in
`Build/old-reddit-local-20261027/archive/`. The sealed manifest identifies each
response by SHA-256. It contains 150 successful page/asset responses (about
9.5 MiB of unique bodies); 134 unavailable asset URLs have explicit empty 404
responses. Some of these URLs occur only in unused CSS rules. Missing assets
stay missing in every trial, so this fixture does not establish pixel parity
with the live website or the supplied screenshot.

`hot.html` and `new.html` beside that directory are readable copies of the page
bodies. The former is the previously downloaded Reddit response; the latter is
the derived post-order fixture described above. Fresh download attempts for
both URLs returned HTTP 403 and are retained in
`Build/page-switch-20261027-local-download/`.

A separate `benchmark-archive/` retains those pages and assets while freezing the
author-visible `Date` clock at the saved capture time. This prevents relative
timestamps from changing pixels between trials. Author scripts, native timers
and `performance.now()` remain enabled. This additional derivation and both
page hashes are recorded in `benchmark-fixture.json`; the original local archive
is unchanged. Use the benchmark archive for reproducible pixel comparisons.

Use `--archive` to load the saved bytes locally. The timing tool starts and stops
a loopback replay server, creates a private certificate for that browser process,
and retains the original HTTPS URLs. This keeps relative assets and the
`old.reddit.com` fast-switch rule applicable. It does not add localhost or file
URLs to the website registry. The server never forwards missing requests.
Replay request logs, manifest/certificate hashes and the selected proxy are saved
with each trial; the browser still gets a fresh private profile and cache.

A single trial can be reproduced with the following command after supplying a
frozen bundle and the local archive. Use a new output directory
and repeat with `--mode on`, then another off/on pair; run a separate on trial
with `--diagnostic` before accepting measurements.

```sh
python3 tools/run_memory_bounded.py --report Build/switch-off.guard.json -- \
  python3 tools/measure_page_switch.py \
  --binary Build/v/Vox.app/Contents/MacOS/Vox \
  --output Build/switch-off --mode off \
  --from-url https://old.reddit.com/r/UkraineRussiaReport/ \
  --to-url https://old.reddit.com/r/UkraineRussiaReport/new/ \
  --from-title 'Ukraine/Russia War Report' \
  --to-title 'newest submissions : UkraineRussiaReport' \
  --archive Build/old-reddit-local-20261027/benchmark-archive \
  --network-policy 'Disk-only HTTPS archive, no forwarding; derived new; frozen Date'
```

For a comparison, pin one completed production bundle for all trials and verify
its executable and native-library hashes. No production rebuild is needed just
to use the local archive. The archive transport checks pass for original HTTPS
hot/new pages and CSS, missing resources and unarchived hosts, and server cleanup;
proxy validation also covers the existing SOCKS route and the HTTP replay route.
The saved archive's hot/new bodies and a downloaded stylesheet also passed a
byte-for-byte local HTTPS load check; its receipt is
`Build/old-reddit-local-20261027/local-load-check.json`.

The earlier local comparison reached native browser execution. Its diagnostic
confirmed `VOX_PAGE_SWITCH reused=true`, with 47 dirty tiles out of 48 (770,048 of
786,432 CSS pixel area repainted). The first off trial published the destination
at 623.93 ms, but its first and two-second captures differed by 63,572 backing
pixels as thumbnails and relative timestamps arrived. The batch correctly
rejected that result and stopped; it provides no accepted off/on timing or
speedup claim. Keep the failed batch and guard exit 1 in
`Build/page-switch-20261026/validation-11/` and
`Build/page-switch-benchmark-12.json`.

The follow-up uses the quiet-window endpoint and the clock-frozen benchmark
archive. Its native probe test explicitly publishes a late document change and
then a chrome-only change, checking that only the former advances the measured
latency. Both native sources pass strict compiler syntax checks, but the new
native test and browser trials have **not executed**: the bounded launch attempt
returned exit 125 with `reason=busy` after a 600-second wait. Its receipt is
`Build/old-reddit-local-20261027/benchmark-1.guard.json`; the prepared batch is
`benchmark-1.py` beside it. No production build was queued. The transport checks
and busy-guard receipts provide no new browser timing evidence.

Document pixels occupy CSS coordinates `(0, 60, width, height)` in the captured
native view; multiply by the recorded backing scale when cropping the PNGs.
Exclude browser chrome from pixel comparisons because native address editing
and focus can legitimately differ. The destination must differ from the source,
and the last changed and settled destination captures must match the control in
every measured trial. Retain early-frame differences as diagnostic evidence.

### Production bundle and fixture identity

The comparison uses a frozen copy of the rebuilt canonical production bundle,
`Build/page-switch-20261026/reused-prod-11.app`. Its executable SHA-256 is
`a1167c7abc73b8b0ac45f1d3eb0f5ace4f1b44375df75dff3108af46f0de2123`.
At the time of freezing, all 22 recorded page-switch validation inputs matched
both the production source snapshot and the previously executed focused-test
inputs. The measurement tool was subsequently extended for local archives and
quiet-window observations; each trial pins its actual tool/probe hashes. The
bundle's executable and
three native libraries match its signed, smoke-tested production build record.
The original production script exited 1 during signing because a compiler
scratch directory remained inside the bundle; removing that directory from the
bundle and repeating signing and strict verification both succeeded. This is
not recorded as a zero exit from the original build script.

Local provenance is retained in
`Build/page-switch-20261026/reused-prod-11-provenance.json`, with the original
build and signature receipts linked there. The frozen native library hashes are:

| Library | SHA-256 |
| --- | --- |
| `libLadybirdVSkiaText.dylib` | `aa9e849b0b6f94b683950fa810403c26cd45d87fa0fa364a5e6d7bf55ee96f12` |
| `libVoxGraphite.dylib` | `b29d745a1b7e44e1a143f1b2a9bca0d9c7874f20ec260f75b119c3ac949ac9e5` |
| `libVoxGraphiteDawn.dylib` | `cb98233f4dd44223964522e972655d739d701da23ddf0a3a4fc794c8722b9b52` |

The archived hot body SHA-256 is
`597f655277b99bf309ef39dbca7e15701aadf0b68857c7f5445c055a2f7bed60`.
The derived new body SHA-256 is
`0b2792387a96393359bb1433dad7d208c433dd55228e8f0f1eee7e6592de10a1`.
Its first announcement remains in place while the other 24 posts are reversed.
Fixture construction and replay receipts are retained in
`Build/page-switch-20261026/fixture.json` and `replay-server-5/`.

## Focused verification

- Registry and persistent settings tests passed, including disabled-by-default
  behavior and independence from the proxy preference. Native settings tests
  exercised Apply, Cancel and preference restoration.
- Six layout cases passed at runtime: changed/removed/unsupported commands,
  glyph positions and font identity, ordered clips/transforms/control groups,
  localized native checkbox invalidation, conservative Bézier/arc/stroke bounds,
  and a parsed rounded-sidebar border that permits native raster reuse.
- The native raster oracle passed at 1× and 2× backing scales, including
  navigation owner/revision checks, multiple or empty damage regions, invalid
  geometry and full-replay fallback.
- The measurement probe compiled with `-Wall -Wextra -Werror` and the Python
  driver passed `py_compile`. The later quiet-window probe and its native
  fixture pass those warning flags with `-fsyntax-only`; runtime verification
  of that extension remains pending as described above.

Local receipts are retained in `Build/page-switch-20261026/`: the
`routes-check.log` and `settings-check.log`, `validation-3/native-final.log`,
and `validation-7/damage-final.log` plus `damage-runtime.json`. The six-case layout
check also passed at runtime in `validation-11/damage-runtime.json`, under its
3 GiB focused budget; the overall comparison batch still failed pixel validation.
Earlier failed build attempts are retained and receive no whole-run pass credit.

The focused follow-up fix `69ad2273` adds conservative bounds for native control
paths and admits scalar rounded borders to raster reuse. It counts as one
completed fix in the verification cadence; no broad-suite reset or
instruction-count savings are claimed. The compiled test runner was audited to
call all six page-switch test entries.
