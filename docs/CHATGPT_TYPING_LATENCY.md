# ChatGPT composer typing latency

Measured on 2026-11-11 with `tools/measure_chatgpt_typing.py` (fresh private
profile, live chatgpt.com through the user's SOCKS route, 1024×880 window,
43 native key events 120 ms apart). The guest composer is the plain
`<textarea id="mobile-composer-prompt">` with `field-sizing: content` and
`max-height: 192px`; Vox grows it from content as Chrome does.
`handled` is the synchronous keyDown handling time; `present` is the delay
until the page view's layer next publishes new contents (not scanout).
The host was heavily loaded by other sessions (load average 60–170), so
latencies are inflated; instruction counts are the stable metric.

## Per-keystroke work at `4aef38d35`

One keystroke costs about 490 M browser-process instructions and 86 ms of
CPU time; `handled` is about 30 ms and `present` about 64 ms (median).
A 10 s `/usr/bin/sample` of the main thread while typing shows three parts:

- **Forced layout from the page's `input` handler (~20 ms).** React calls
  `getClientRects()`, which runs `Document.update_layout` for the
  `character_data_replace_data` edit. No tree rebuild happens, but every
  ancestor of the textarea lays out uncached: about seven nested grid/flex
  levels, each re-measuring the edited branch for min/max-content. The
  retained block/grid caches reject the subtree (its UA shadow tree and edited
  text are inputs), and the edit clears every ancestor's intrinsic-size cache.
- **Frame drawing (~20 ms).** The composer's corner-shape box and its CSS
  effect layer re-record a picture every frame, serialize it with embedded font
  bytes, create a new IOSurface/Metal texture and wait for a synchronous GPU
  readback (`ladybird_v_skia_draw_contoured_box`,
  `native_end_css_effect_layer`).
- **Script-commit shell relayout (~3–7 ms).** Each keystroke's JS task has
  compact replay effects, so `synchronize_javascript_task_paint` runs
  `BrowserApp.relayout`: two style updates, the adblock cosmetic refresh
  (token survey, worker round trip, cookie-banner walk) and paint recording.

## Media rule evaluation memo (`a3815456c`)

Every style update re-evaluated each sheet's `@media` rules, twice per
keystroke here. A sheet now skips evaluation when the document, the media
inputs (viewport size, color scheme, reduced motion/transparency, device pixel
ratio, font geometry policy) and the rule-structure generation are unchanged;
`MediaList` edits and late `@import` sheets advance the generation.
`VOX_DISABLE_MEDIA_EVALUATION_MEMO=1` restores the old behavior.

Same-binary A/B, three alternating pairs, memo off → on:

| Pair | Instructions/key | CPU ms/key | `present` median |
| --- | --- | --- | --- |
| 1 | 514.2 M → 490.2 M | 92.1 → 88.9 | 69.1 → 65.0 ms |
| 2 | 514.1 M → 487.9 M | 91.5 → 85.4 | 68.9 → 62.6 ms |
| 3 | 520.6 M → 492.6 M | 93.8 → 86.9 | 71.6 → 66.7 ms |

About 5% fewer instructions per keystroke, 3/3 pairs. The opt-in GPU reuse
switches (`VOX_REUSE_DAWN_REGION_RECORDER`, `VOX_REUSE_DAWN_REGION_TARGET`,
`VOX_SHARED_PICTURE_TYPEFACES`) were inconclusive on this workload (two pairs,
one better, one equal).

## Text-control relayout (`96c727d87`)

Layout invalidations now record where they originate. When every origin
since the previous pass lies inside textarea/text-input editors (no tree
rebuild; same viewport, fonts, style environment and replaced natural sizes),
the pass restores the previous geometry and repeats only each control's last
committed inner layout. It is kept only if the control's automatic block size
(and inline size when not already definite) and baselines are unchanged;
otherwise the complete pass runs. The first character of an empty editor, a
taller fallback-font glyph, a new line in a growing textarea and any change
outside the control all take the complete pass.
`VOX_DISABLE_TEXT_CONTROL_RELAYOUT=1` disables it,
`VOX_TEXT_CONTROL_RELAYOUT_DIAGNOSTICS=1` reports each decision and
`VOX_VERIFY_TEXT_CONTROL_RELAYOUT=1` compares every accepted pass with a
complete one.

Live ChatGPT on a private `-prod` single-unit bundle, same binary, three
alternating pairs (kill switch on → off):

| Pair | Instructions/key | keyDown handled (median) | `present` median |
| --- | --- | --- | --- |
| 1 | 469.9 M → 311.6 M | 47.4 → 13.7 ms | 99.7 → 69.7 ms |
| 2 | 473.2 M → 320.2 M | 36.6 → 11.2 ms | 89.5 → 62.8 ms |
| 3 | 467.2 M → 319.0 M | 41.0 → 9.4 ms | 92.6 → 57.0 ms |

Host load averages were 42–58. With verification enabled, 42 of 45 keystroke
passes took the fast path and all matched the complete pass with zero
geometry mismatches; three fell back on unrelated DOM changes.
`browserapp/text_control_relayout_test.v` (4 cases) and
`browserapp/keyboard_input_test.v` (12 cases) pass with the default
collector; the new tests also pass under the verifier with zero mismatches.
Under `-prealloc -gc none` the new test file crashes in an ordinary complete
pass (`Document.cursor_position` during grid intrinsic sizing) with the
feature disabled as well; that fixture problem predates this change.
Layout-module `_test.v` files currently exhaust the 10 GiB compiler limit
even at an unmodified checkout, so the focused tests live in `browserapp/`.

## Layer leaf deferral in reused frames (`889e8d552`)

Each keystroke frame reuses the previous viewport pixels and repaints one
damage rectangle (96 of 109 paint commands skipped). The composer is a
compositor layer whose picture is published within the command replay, yet
its border and shadows were also rasterized immediately as leaves, because
frames stored for scroll reuse disabled deferral to protect speculative root
pictures that publish after the store. Those frames now defer leaves into
non-speculative compositor-layer pictures only. On ChatGPT the border and two
of the three shadows defer; the third shadow's blur extends beyond the layer's
publication bounds and stays immediate.
`VOX_DISABLE_REUSED_FRAME_LAYER_DEFERRAL=1` restores the previous behavior.

A fixed-composer fixture's final frame is byte-identical between the new
mode, the control and complete repaints. Live ChatGPT, same private `-prod`
bundle, three alternating pairs (switch on → off):

| Pair | Instructions/key | `present` median |
| --- | --- | --- |
| 1 | 319.1 M → 288.4 M | 71.2 → 63.4 ms |
| 2 | 327.0 M → 308.3 M | 73.7 → 55.9 ms |
| 3 | 326.0 M → 295.7 M | 50.0 → 48.9 ms |

Host load averages were 27–32.

## Layer typefaces and shadow deferral (`3e4d96329`, `54727569c`)

Each keystroke republishes the composer layer's picture. Its serialization
embedded the complete system font file, which the GPU decoder compared again
byte by byte. Layer publications now lease fonts by 16-byte token through a
typefaces-only `SharedPicturePixelsScope`; image encoding is unchanged
(`VOX_DISABLE_SHARED_LAYER_TYPEFACES=1` restores embedded fonts). Same-binary
ChatGPT pairs: 324–339 M → 304–310 M instructions per keystroke (3/3).

The composer's outer shadow still rasterized immediately with its own GPU
readback, because its fallback-bitmap blur margin did not fit the layer's
publication bounds. The picture records the shadow's three-sigma blur extent,
beyond which the mask blur paints nothing; shadows now defer when that extent
fits (`VOX_DEFER_CONTOURED_SHADOWS_BY_FALLBACK_MARGIN=1` restores the old
test). Same-binary pairs: next frame publication medians 26.7/26.3/26.3 →
21.9/21.8/21.5 ms. Native tests rasterize leased/embedded pictures and
deferred/immediate wide and overflowing shadows with identical pixels; the
fixed-composer fixture's final frame is byte-identical across the new path,
the control and complete repaints. On a quiet host a keystroke now takes
about 5–7 ms to handle and 20–22 ms to the next frame publication.

## Remaining work

A 10 s main-thread sample now spends about half its time idle. The rest:

- **Layer picture raster** (~25% of frame time): the composer layer is
  re-rasterized as GPU tiles with a synchronous readback every keystroke.
- **Script-commit shell relayout**: cosmetic-filter token survey and worker
  query, cookie-banner walk, and the pending style flush. The light-DOM
  id/class token stamp is still scoped to GitHub.
- **Rendering-update style**: per-keystroke style recomputation plus sampling
  of the page's running CSS animations.
- **Paint-tree projection** rebuilt after each fast text-control relayout.
- **Full-window bitmap copy** (`CGBitmapContextCreateImage`) and the tab
  session poll, which locks and rewrites `state.json` on every frame.
- Vox ignores `field-sizing` in layout; textarea growth here comes from its
  content-derived automatic height, not from the property.
