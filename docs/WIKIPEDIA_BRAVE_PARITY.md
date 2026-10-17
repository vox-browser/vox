# Wikipedia rendering against Brave

**Exact Brave pixel equality has not been reached.** At a 1024×768 viewport
and device scale 2 (2048×1536 pixels), Vox with JavaScript enabled differs from
Brave at 1,916 pixels (0.061%). The remainder is SVG anti-aliasing in three
sister-project logos (thin strokes and clip paths) and a few isolated pixels.

Vox normally loads wikipedia.org without page JavaScript (`html_css_only_sites`
in `main_script_policy.v`), but Brave runs Wikipedia's portal script. The
default launch therefore shows the full language list where Brave shows the
collapsed "Read Wikipedia in your language" button. It differs from Brave at
736,583 pixels (23.415%). Pass `--enable-javascript`, or remove wikipedia.org
from that list, to get the script-driven layout.

## Method

- **Reference:** Brave 155.1.97.57 (Chromium 155) on macOS, captured on
  2026-10-16 from https://www.wikipedia.org/ in a fresh headless profile, with
  and without page JavaScript:

  ```sh
  python3 tools/capture_brave_reference.py --url https://www.wikipedia.org/ --out brave.png
  python3 tools/capture_brave_reference.py --url https://www.wikipedia.org/ --no-js --out brave-nojs.png
  ```

- **Vox:** the native window was captured at device scale 2, and the 88px
  toolbar (176 device pixels) was cropped:

  ```sh
  LADYBIRD_SCREENSHOT_SCALE=2 LADYBIRD_SCREENSHOT_DELAY_SECONDS=4 \
    Build/v/Vox.app/Contents/MacOS/Vox --enable-javascript \
    --window-width 1024 --window-height 880 --screenshot window.png https://www.wikipedia.org/
  sips --cropToHeightWidth 1536 2048 --cropOffset 176 0 window.png --out vox.png
  ```

- **Comparison:** every channel difference counts. No tolerance or masked
  region is used.

| Capture | Differing pixels | Percentage |
| --- | ---: | ---: |
| JavaScript enabled, before | about 236,000 | 7.5% |
| JavaScript enabled, now | 1,916 | 0.061% |
| JavaScript disabled in both, before | about 297,000 | 9.44% |
| JavaScript disabled in both, now | 113,567 | 3.610% |
| Default Vox (no JavaScript) against Brave | 736,583 | 23.415% |

## Chromium compatibility policy

The work shares the Chromium compatibility policy (`font_rendering_policy`)
introduced for old Reddit. Navigation selects it for old.reddit.com and for
wikipedia.org and its subdomains, and SVG image documents inherit it from the
page that embeds them. Other documents and the layout test suites keep
LibWeb's behavior.

## Wikipedia-specific changes

- **Font matching:** installed faces are matched through CoreText as Chromium
  does on macOS:
  - system-ui uses SF with its optical-size and weight axes.
  - The default, serif, sans-serif and monospace families use Times, Helvetica
    and Courier.
  - Han, Kana and Hangul use the per-language Chromium preferences, and other
    scripts use CoreText fallback.
  - HarfBuzz shapes with the selected face's variation coordinates. The
    installed HarfBuzz 14.5 replaces vcpkg's 10.2, which lacked PingFang's
    `trak` tracking.
- **Line metrics:**
  - Ascent, descent and leading come from CoreText, as Skia passes them to Blink.
  - Times, Helvetica and Courier receive Blink's legacy 15% ascent adjustment.
  - The x-height is the top of the `x` glyph's bounds.
  - The root strut sits on the line's baseline.
  - With `line-height: normal`, the line box grows to include the fallback
    faces the text uses.
- **Text items:**
  - A text node is rounded as one Blink item across fallback fonts and CJK
    break opportunities, and its glyphs keep unsnapped offsets.
  - Spaces are shaped with the first font that covers them.
  - Mixed-font text paints its own shaped glyph runs.
- **SVG:**
  - Filled and stroked paths and gradients are drawn through the Graphite
    backend, matching Chromium's GPU coverage.
  - Gradients are dithered on the page's pixel grid.
  - `objectBoundingBox` gradients use the bounding-box transform.
  - A clip path inside a nested `<svg>` viewport is no longer offset twice.
- **Painting:**
  - Text paints from a whole-pixel box top.
  - Backgrounds and background-image clips use the pixel-snapped border box.
- **Layout:**
  - A later float that clears leaves inline content beside the earlier floats.
  - Select labels fill the select's used height.
  - srcset candidates are chosen for the display's device pixel ratio.
- **Script bridge:** it exposes `parentNode`, `parentElement`,
  `classList.replace` and `select.value`, so the portal script inserts the
  "EN" language label.

The public Brave fixtures `svg-path-coverage` and `fallback-text-items` in
`Tests/Browser/Brave` reproduce these cases and are pixel-identical. The old
Reddit gate and every other Brave fixture remain exact.

## Remaining differences

- **Thin SVG strokes and clip paths:** the Wiktionary logo's strokes are about
  0.5 device pixels wide, and Vox applies SVG clip paths (the Commons and
  Wikimedia logos) as Quartz masks. Chromium's GPU coverage differs slightly
  at those edges.
- **No-JavaScript language list:** Vox does not implement CSS multi-column
  layout (`column-width`), which accounts for most of the no-JavaScript
  comparison.
- **Live content:** Wikipedia's article counts change. Compare references and
  captures taken from the same page version.

## Validation

Each change has focused tests that pass in the default and `-gc none` builds.
Each also passed:

- every `Tests/Browser/Brave` fixture and the old-Reddit exact gate;
- the eleven default screenshot smoke cases;
- the eight pixel-exact SVG regression reftests;
- the native Skia clip test.
