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

## Remaining work

- **Text controls as relayout boundaries.** The large saving needs the
  retained block and grid-measurement caches to treat a textarea/text input as
  an opaque input: collect its style but not its UA shadow subtree, re-lay out
  only its inside on reuse, and accept the reuse only when the control's
  clamped automatic height and its baseline (empty versus non-empty) match the
  snapshot. Ancestor intrinsic-size caches must be kept or revalidated the same
  way. The fixed footer and its `container-type: inline-size` grid stay
  uncached, but their children could then be reused.
- **Effect-layer and corner-shape rasterization** without per-frame surface
  creation, font-byte serialization and synchronous readback.
- **Cosmetic-filter refresh per script commit.** The light-DOM id/class token
  stamp is scoped to GitHub; other sites re-survey on any attribute change and
  query the filter worker every commit even when the tokens are unchanged.
- Vox ignores `field-sizing` in layout; textarea growth here comes from its
  content-derived automatic height, not from the property.
