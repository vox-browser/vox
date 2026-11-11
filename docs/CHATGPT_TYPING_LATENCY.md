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

## Remaining work

- **Frame drawing** is now the largest per-keystroke cost: the composer's
  corner-shape box and CSS effect layer re-record a picture every frame,
  serialize it with embedded font bytes, create a new IOSurface/Metal texture
  and wait for a synchronous GPU readback.
- **Cosmetic-filter refresh per script commit.** The light-DOM id/class token
  stamp is scoped to GitHub; other sites re-survey on any attribute change and
  query the filter worker every commit even when the tokens are unchanged.
- The fast path covers text controls only. Other edits still lay out every
  uncached ancestor; a general size-unchanged relayout boundary in the
  retained block/grid caches would extend it.
- Vox ignores `field-sizing` in layout; textarea growth here comes from its
  content-derived automatic height, not from the property.
