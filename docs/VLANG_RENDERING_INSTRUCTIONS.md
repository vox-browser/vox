# vlang.io rendering instructions

On 2026-10-30, the pinned production Vox bundle averaged **10.142 billion
observed retired CPU instructions**, versus **10.453 billion for Brave**, across
17 completed, matched captures of a frozen vlang.io page: **2.97% fewer**.
Vox preserved every baseline viewport pixel. The live site was also checked in
fresh processes at the top and at a 3000 CSS-pixel scroll offset.

This result measures startup through a document PNG capture of a fixed page.
The archived DOM has its author scripts removed and CSS animations/transitions
disabled. JavaScript policy remains enabled in both browsers. Live scripts,
video playback, scrolling throughput and display presentation are outside the
comparative measurement.

## Results

All instruction figures below are billions. Every completed final Vox/Brave
pair is included, including the pairs captured before an unrelated, older Vox
control timed out later in that wave.

| Browser | Captures | Mean | Median | Minimum | Maximum |
| --- | ---: | ---: | ---: | ---: | ---: |
| Final Vox | 17 | 10.142 | 10.191 | 9.657 | 10.938 |
| Installed Brave | 17 | 10.453 | 10.466 | 10.342 | 10.563 |

Vox used fewer instructions in 14 of the 17 pairs. Three Vox trials used
4.1–5.3% more than their paired Brave trial. A paired bootstrap with 20,000
resamples and seed `20261030` gives a descriptive 95% percentile interval of
0.92–4.82% for the mean reduction. This interval describes the recorded
workload and host conditions; individual runs vary with resource completion
and layout scheduling.

The first eight alternating control/Brave/candidate waves, retained in
`acceptance-image-wakes/`, averaged 9.976 billion for final Vox, 10.500 billion
for the preceding Vox bundle, and 10.486 billion for Brave. All eight candidate
captures were below Brave. The additional completed pairs narrow the overall
margin to the 2.97% reported above.

A separate comparison against the initial Vox bundle averaged 14.279 billion
for that bundle and 10.302 billion for final Vox over eight valid matched
triples: **27.86% fewer instructions**. The initial bundle's eighth capture
timed out after 90 seconds. That old-control measurement is invalid; its log
and failed guard receipt remain retained. The entire eighth triple was
repeated successfully in `acceptance-initial-retry/`. Both completed final
Vox/Brave pairs from that wave remain in the 17-pair comparison above.

## Changes

- `0ce0924a`: compute only the grid item contributions consumed by each
  flexible-track sizing phase, avoiding unused nested layout measurements.
- `02685427`: retain a grid item's geometry when final row sizing leaves its
  height unchanged and its descendants do not require another height-dependent
  layout. Percentage dependencies, replaced controls and subgrids retain their
  full layout paths.
- `77ee14c5`: defer native `loading="lazy"` image requests until valid geometry
  places them near the viewport. Scrolling and reveal changes resume requests;
  cancellation and source replacement discard obsolete completions. Documents
  with scripting disabled retain eager loading.
- `7f158232` and `de0fbc2f`: consume PageClient, image and navigation repaint
  requests in the native preparation that adopts their changes. Requests made
  during replay and worker notifications retain their subsequent frame. Batch
  captures also wait for pending background resources before replaying document
  pixels.
- `11a70806`: cache CoreText synthesized-hyphen results, including valid negative
  results, on the owning HarfBuzz face. Different text sizes share the lookup;
  face retirement releases its payload. This avoids repeatedly copying large
  font tables, including Apple Color Emoji.
- `3b0182e4` corrects the native presentation test fixture's RGBA byte order to
  match the existing production frame format.

A separate attempt to initiate font requests during tree construction was
tested and rejected. Its eight comparison waves averaged 10.579 billion for
the experimental candidate, versus 10.302 billion for its control. That code
and its temporary API are absent from `master`; the results remain in
`acceptance/`.

## Workload and counters

The fixture is an initialized vlang.io DOM snapshot with 31 archived assets,
local font files, and a fixed video poster. All resource URLs are rewritten to
the local archive. The fixture HTML SHA-256 is
`dcf945273ed128180fa6f683d871ca4b1ef958ed8df4e366c1d4e31273f8589b`.
Separate diagnostic captures establish identical complete body-text SHA-256
in Vox and Brave:
`4666f815aad7ef0eabb48cf283379c894dbe30eb21f6ae2143c5628bf52711e7`.

Each trial launches a fresh process with an empty private profile and cache.
The document viewport is 1024×768 CSS pixels; native window PNGs are 1024×852
pixels before cropping the 60-pixel toolbar and 24-pixel status bar. Capture
uses one raster pixel per CSS pixel. The archive is served over loopback HTTP;
proxy environment variables are removed, and Brave disables proxy use and
external DNS resolution. Both browsers use the same archived bytes. Native
instruction phase logging, capture audits, injected probes and timing traces
are disabled for the final comparison. Captured Vox pixels are checked by the
external observer after the instruction endpoint.

`tools/measure_browser_instructions.py` and `tools/process_instruction_counts.py`
read macOS process counters at a nominal 5 ms observation cadence. Vox's root
counter is sampled from its unreaped zombie after capture and teardown; all
final Vox trials have complete final samples for their observed processes and
no unreadable PIDs. Brave's endpoint is the completed document and first CDP
screenshot response, before shutdown. Its last observation can precede that
response by several milliseconds, and some transient children lack a final
sample. The totals are observed process-tree lower bounds. GPU instructions
and work in shared system services are excluded. No startup subtraction or
wall-time conversion is applied.

The host is an 18-CPU Apple M5 Max running macOS 27.2. Final trials span
13:14:33–13:27:03 UTC; candidate launch-time one-minute loads range from 16.17
to 24.02. Controls and candidates alternate within each wave. Host contention
and asynchronous font completion contribute to variation; per-trial load,
timestamps, counter coverage and regressions remain in the reports.

## Build identity and verification

The final executable SHA-256 is
`c90d4d64a633ed98162900cecc7fbcafa80063ff6450a558a72e5982395dda5a`.
The preceding control is `caed80c170ae23d2…`; the initial control is
`ae1c0d8dc8bb061d…`. Brave is version `156.1.98.60`, with executable SHA-256
`9d53e182ab59b7c430abea0233088cb452694b96843d62ccccbc6c0902b98fe5`.
Full executable, helper and native-library hashes are retained in
`image-wakes-identity.json`, the individual trial reports, and
`external-library-identities.json`.

The final V feature inputs match their production build's before/after source
hashes. The shared checkout also received SVG and PNG changes while builds
ran; changed input lists are retained in `production-*-result.json`. These
measurements compare the pinned bundles as a whole and do not isolate the
instruction contribution of each commit or concurrent change.

Focused verification includes:

- The grid regressions and 315 layout tests in both default GC and `-gc none`.
- The image/frame/navigation batch's 24 test functions in both memory modes,
  including consumed preparation wakes and later resource delivery.
- Eighteen HarfBuzz, hyphen, emoji, coverage and cache-lifetime functions in
  both memory modes. The native font-cache test checks glyphs, advances,
  negative results and retirement across 32 sizes for Arial, Times New Roman
  and Apple Color Emoji.
- Native retained-frame and capture tests under ARC and MRC, including actual
  RGBA pixels, unfinished preparation, replay-time and worker notifications.
- All 11 default screenshot cases, plus nine exact SVG source/paint-server
  mutation comparisons. The first SVG command passed three cases before a
  path-resolution error; the remaining six passed with explicit input paths.
- Production headless startup and strict bundle signature verification.
- Fresh live `https://vlang.io/` captures with author scripts enabled, complete
  documents and loaded fonts, at offsets 0 and 3000. Visible HTML images have
  completed requests and natural dimensions; the top screenshot was inspected
  directly. The initial live observer used an incorrect audit-schema key, then
  treated an unused paint-cache field as a loading failure. The retained native
  capture was valid; corrected validation is saved without recapturing it.

Eligibility was checked separately from the instruction trials. The final
redraw trace contains 22 preparation requests from lazy-image deferral and 15
completion-related stacks from image polling. The font probe records 31
face-cache queries, 25 hits and six initializations. Its caller is validated
against the actual executable header and the `scaled_harfbuzz_font_with_policy`
symbol range. Earlier unsuccessful probe attempts are retained and excluded.

## Evidence and reproduction

All raw captures, commands, logs, source receipts and guard exit codes are
under `Build/vlang-instructions-20261030-1540/`. The principal records are
`final-assessment.json`, `acceptance-image-wakes/summary.json`,
`acceptance-initial-assessment.json`, the `live-image-wakes*` records, and the
`smoke-image-wakes*` / `smoke-svg-image-wakes*` records. Earlier instrumented
`frozen-*` and profile runs are diagnostic evidence, excluded from final
instruction statistics.

The local archived fixture and pinned bundles can be rerun with a new output
directory:

```sh
vlang_run_dir=Build/vlang-instructions-20261030-1540
python3 tools/run_memory_bounded.py --limit-gib 3 \
  --lock "$vlang_run_dir/reproduction.lock" \
  --report "$vlang_run_dir/reproduction.guard.json" -- \
  python3 "$vlang_run_dir/measure_acceptance.py" \
  --output acceptance-reproduction-1 --repeat 8 \
  --control "$vlang_run_dir/candidate-hyphen.app/Contents/MacOS/Vox" \
  --candidate "$vlang_run_dir/candidate-image-wakes.app/Contents/MacOS/Vox"
```

Expensive builds used the shared production lock, the default 12 GiB sampled
RSS guard, and V's `-memory-limit 10G`. Runtime tests and browser captures used
separate 3 GiB guards. The final production build exited successfully with a
sampled peak aggregate RSS of 6,054,199,296 bytes; the primary comparison guard
peaked at 1,073,250,304 bytes. The original-bundle timeout retains its actual
failed observer/guard exit status and supplies no old-control acceptance credit.
