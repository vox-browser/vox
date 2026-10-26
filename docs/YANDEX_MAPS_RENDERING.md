# Yandex Maps rendering comparison

Target: <https://yandex.ru/maps/2/saint-petersburg/?ll=30.248557%2C59.948999&z=15.04>.
Pixel-perfect live parity with Brave remains **incomplete**. The browser uses
JavaScriptCore; these changes do not establish LibJS runtime parity.

## Completed fixes

The compact script bridge now preserves native input values, replaces children
when assigning the same `textContent`, implements connectedness and containment,
forwards scrolling, installs Fetch on the actual browser window, and reports
native asynchronous script errors in capture audits. Focused tests accompany
these changes (`4e440d3d`, `403f9f9c`, `2648cd49`, `96fd0e16`, `a5fa0120`,
`6d9b3ab7`, `1302403f`, `e756b683`, `40d9edf3`).

`053c8cc0` keeps Chromium-policy U+2010/U+2011 hyphens in the selected macOS
font when CoreText supplies a synthesized glyph absent from its raw cmap.
Existing cmap glyphs, Unicode clusters, advances, cache lifetimes, and the
LibWeb policy remain covered by focused tests. This corrects the Yandex heading
and the weather widget's horizontal position.

`e55a6d22` retains full-opacity compositor surfaces for the Chromium policy's
transform, translate, rotate, scale, perspective and transform-style
`will-change` hints. The hints are suppressed below `will-change: contents`,
including through unboxed ancestors and shadow-DOM slots. Existing 3D-transform
surfaces survive that suppression; opacity and hint surfaces coalesce.
This follows Chromium's
[compositing reason selection](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/third_party/blink/renderer/core/paint/compositing/compositing_reason_finder.cc).
The new `will-change-transform-shadows` fixture improves from 13,134 differing
pixels to zero at 800 × 600, scale 1. This independently verified correction
does not reduce the archived map's remaining 4,967 differing pixels.

## Latest reproducible archived comparison

Both browsers render the same script-free archived DOM at 1024 × 768 logical
pixels, backing scale 1, with an eight-second settle period. External resources
still use the network; this is not an offline fixture or a live-site acceptance
run. Every capture starts a new process and private profile.

| Measurement | Before synthesized hyphens | After |
| --- | ---: | ---: |
| Differing pixels / 786,432 | 5,779 | 4,967 |
| Differing fraction | 0.73484% | 0.63159% |
| Mean absolute channel error | 0.0557243 | 0.0140216 |
| Maximum channel error | 134 | 64 |

The heading's rectangle now matches Brave at `(24, 73, 164.140625, 24)`;
the weather widget starts at `x = 196.140625`. The remaining differences are
mostly single-channel color steps around map-control shadows, plus several
text glyphs in the sidebar error message. These counts are exact pixel
comparisons, not a perceptual similarity score.

Local evidence under `Build/yandex-maps/`:

- `coretext-hyphen-recovery-1792979076217380000/`: both screenshots, heatmap,
  pixel metrics, final DOM audit, source-scope receipt, process receipts, and
  executable/native-library identities.
- `production-1792973150463471000/maps-live-brave-fetch-direct.html`: archived
  DOM, SHA-256 `13df4839bc5bb7158ed84806bc432fdb188aa79f1b779313b03c41ea8d210383`.
- `coretext-hyphen-production-1792978459674938000/Vox.app`: preserved tested
  bundle; executable SHA-256
  `a00aee0a9130b0cb57bd66f83af3a4eb404bfddfc2b4df0bc14517ea78f009f0`.

The four changed font files stayed identical through build and capture.
Unrelated source files changed during the shared-checkout build; the
`source-scope.json` receipt records this limitation. The preserved bundle and
its native libraries, rather than the later working tree, identify the result.

## Validation and limits

All six focused font test files pass; the four new hyphen tests also pass with
`-gc none`. Production build, startup smoke check and code signature pass.
All nine SVG image/paint-server mutation comparisons remain pixel-exact. The
installed/file-backed hyphen rendering reftest is exact at 400 × 180.

The original production validation exceeded the default 12 GiB RSS guard while
loading a large base64 font fixture and was killed. Its failed guard receipt is
retained as `coretext-hyphen-production-guard.json`. Retrying with the same font
in a separate file and the verified preserved bundle completed successfully;
`coretext-hyphen-recovery-guard.json` records exit 0 and peak sampled process-tree
RSS of 9,599,107,072 bytes. The budget was not raised.

The latest fresh headless Brave live capture returned “Are you not a robot?”.
Its pixels are excluded from acceptance metrics. Vox loaded the map, but that
alone cannot prove matching live state or pixel-perfect rendering. A valid
fresh live reference and zero differing pixels are still required.

## Transform-hint verification

The nine transform-surface tests pass with both Boehm and `-gc none`; the
raster-layer tests also pass. Production build, startup and signature checks
pass. All six controlled map-shadow palette cases and the existing
`box-shadow-blur`, `opaque-box-shadow` and `scroll-overlap-gradient-layer`
references are pixel-exact. Broader suites are not credited for this slice.

Evidence is retained in `transform-hints-focused-1792982221259709000/` and
`transform-hints-production-1792982479436352000/` under `Build/yandex-maps/`.
Their guard receipts record exit 0 and peak sampled process-tree RSS of
8,374,091,776 and 9,641,984,000 bytes respectively. The tested implementation
and fixtures stayed unchanged. One unrelated CSS test changed during the
production build; the source-scope receipt records it. The preserved tested
executable's SHA-256 is
`235819c3007251306a780a235bf810494a72272651e444215f211992b4eafd8e`;
`identity.json` also records its native libraries.

The same archived DOM still differs at 4,967 / 786,432 pixels, with MAE
0.0140216 and maximum channel error 64. The fresh live Brave reference again
returned the robot check and is excluded from acceptance metrics.

## Cyrillic context shaping

`e2e364fc` extends Chromium-policy shaping across soft word boundaries to
single-script Cyrillic runs. A hyphen can now retain its kerning context in
“Что-то”, including inside an LTR isolate. Mixed scripts, font changes, hard
breaks and unsupported scripts retain segmented shaping. Runs whose glyphs
repeat a multi-glyph cluster's UTF-16 span also retain segmented shaping;
summing those spans cannot identify safe chunk boundaries.

The focused checks pass eight context-shaping cases in both Boehm and
`-gc none`, plus the precise-inline-advance regression in Boehm: 17 executed
cases. The controlled `cyrillic-context` fixture improves from 2,312 differing
pixels to zero against a fresh Brave capture at 800 × 600, scale 1. Its
file-backed test font contains original rectangular glyphs and a deliberate
cross-boundary kerning pair; it avoids depending on installed-font kerning.
The font generator reproduces SHA-256
`dc9d355e69cdfa05e0a40227d8c548bdb1270d2e42a05844f0f845c1fdf14e5f`.

Evidence is retained under `Build/yandex-maps/` in
`cyrillic-context-focused-1792988060569311000/` and
`cyrillic-context-cluster-focused-guard.json`. Compilation, actual test
execution and captures exited zero; the guard's sampled peak RSS was
8,410,120,192 bytes. The six implementation/test/fixture source hashes stayed
unchanged. The exact fixture capture used the preceding preserved Cyrillic
bundle; the final multi-glyph-cluster fallback is covered by the focused
runtime checks. A rebuilt production bundle still requires separate visual
verification.

The production comparison retained fresh baseline/reference captures in
`cyrillic-context-production-1792988556062138000/`, then exceeded its
900-second build deadline during C compilation. Its guard reports child exit
1, `remaining_children`, and peak sampled RSS 6,988,578,816 bytes; no production
pass is credited. Production-only recovery carries those completed captures
and uses a longer build deadline within the unchanged memory budget. Full-map
improvement and the queued broader checks are not yet credited.


## Unused perspective raster contexts

`5e6cc65b` delays the whole-document raster fallback until a paint command
actually uses a perspective or scroll-compensation context. Unsupported state
propagates through descendant contexts, so painted perspective descendants
still use the conservative root fallback. Empty perspective containers no
longer disable independent scroll layers; their own backgrounds retain the
ordinary parent context. Reusing the planner clears the retained state.

All ten raster-layer cases pass with both Boehm and `-gc none`, including three
new cases for unused perspective, painted descendants, and referenced versus
unused scroll compensation. Compilation and actual execution exit zero; the
three implementation/test hashes stay unchanged. Evidence is retained in
`Build/yandex-maps/unused-raster-context-1792990767506049000/focused-1792992189956745000/`.
The preceding attempt failed during C compilation because the private staged
harness omitted a sibling native-header path; no tests ran in that attempt.

Production eligibility, full-map pixels, and the broader regression checkpoint
remain pending. This focused renderer correction does not establish live-site
or JavaScript-engine parity.
