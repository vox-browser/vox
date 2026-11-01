# CNN rendering against Brave

The registered CNN archive now renders with **zero differing RGBA pixels**
against Brave 156.1.98.60 with full uBlock Origin 1.75.0. This result covers
1024×768 CSS pixels at scale 1, original-origin replay, and complete encoded
response caches. Each browser warms its cache in a discarded process and then
captures from a fresh process. The unchanged archive contains 85 responses,
14,846,886 bytes; its manifest SHA-256 is
`f5ae5e4153a54a8da720d4a9cd6775bf23ae4541512dbd850eb533ba5109ed1d`.

The original matched-cache result was 224 differing pixels, all with a maximum
channel error of one. The header, ticker fade and photo corners now match.
Two independent fresh native captures are exact, including the registered
full-uBO runner. The Brave reference is byte-identical to the original control.
No existing reference, tolerance or excluded region changed.

The full site runner still exits 1: the saved live PNG differs from the frozen
Brave replay at 101,696 pixels. Its `live-to-frozen-mismatch` gate remains in
force. This establishes archived rendering equality, with cold-load decoding,
fresh live capture stability, author JavaScript and video playback still outside
this result. Earlier unstable live recapture attempts are retained in the
[site history](ADBLOCK_POPULAR_SITES.md#cnn-svg-background-eligibility-1-november-2026).

The fixes preserve paint metadata around captured masks and filters, retain
initial requests for generated images without dimensions, resume opaque header
pictures across masks, and retain fractional SVG background viewports inside
independently sampled picture shaders. Offscreen leaves now receive the same
culling decision before picture eligibility as they do during native replay.
A distant unsupported SVG background therefore cannot disable a visible ticker
picture. Resource boundaries and visible unsupported content retain their
existing replay path.

Focused coverage includes four registered CNN screenshot fixtures: solid and
repeated SVG header backgrounds, the rounded header with a captured mask,
and fractional SVG backgrounds; the ticker fixture adds a fifth CNN case.
All five and two related compositor/gradient fixtures pass exactly. The new
ticker fixture changes from 63 pixels in the preceding bundle to zero, against
two agreeing Brave references. Fractional-background V tests pass with default
GC and `-gc none`; the preallocated SVG cache ownership/refresh test also passes.
The compositor culling file passes all four cases. Native shader checks cover
24 matrix/filter/backdrop combinations and 120 unchanged failure paths with a
sanitized driver. Fresh headless startup passes.

Run the native API checks with `python3 tools/test_graphite_svg_pattern.py`.
CNN remains registered in `Tests/Browser/Brave/forum-news.json`; reproduce the
full comparison with `tools/forum_news_pixels.py --sites cnn --cache-policy
complete` and the full-uBO extension, checker and closed profile documented in
[the site report](ADBLOCK_POPULAR_SITES.md).

The tested executable SHA-256 is
`80ce4baab9127245c859c17522365eec2e65600c23c5d11df51f86ac7ed070cf`.
Native-library identities, exact commands, guard exits and retained observations
are recorded in the [durable receipt](benchmark-results/cnn-brave-pixels-2026-11-01.json).
The production build completed while other sessions changed UI and image-cache
files. The CNN eligibility and fractional-viewport sources stayed unchanged;
the receipt preserves every changed input and pins the actual tested bundle.

Raw evidence is under `Build/cnn-zero-20261101/`: `full-control/`, `full-final/`,
`visible-site/`, `ticker-visible/`, `visible/identity.json`, `visible-pixels.log`,
`native-pattern-final/`, the focused compile/run receipts, and
`production-visible-2/`. Intermediate regressions, diagnostic overrides and the
failed UI-migration build are retained separately and supply no acceptance credit.
