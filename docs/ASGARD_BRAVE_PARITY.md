# AsgardPvP rendering against Brave

All nine viewport comparisons below are **pixel-exact**, including normal
Retina windows and scrolled content. Comparisons require identical RGBA pixels,
without a tolerance or excluded regions. Only browser chrome is cropped.

References use Brave 155.1.97.59 on macOS. Both browsers reach
`https://asgardpvp.com/` through the SOCKS5 proxy on `127.0.0.1:1337`.
The original reference PNGs are unchanged. These measurements cover the listed
viewports and scroll positions; they do not establish parity for other pages
or every possible interaction.

## Measured results

A 2× viewport has two device pixels per CSS pixel in each axis. Normal-window
Brave references use the display's real scale, without device-metrics emulation.
All captures use sRGB.

| Capture mode | CSS viewport | Scale | Scroll Y | Differing pixels | Maximum channel error |
| --- | --- | --- | --- | --- | --- |
| Controlled | 800×600 | 1× | 0 | 0 | 0 |
| Controlled | 1280×800 | 1× | 0 | 0 | 0 |
| Controlled | 1024×684 | 2× | 0 | 0 | 0 |
| Controlled | 1280×800 | 1× | 800 | 0 | 0 |
| Controlled | 1280×800 | 1× | 1600 | 0 | 0 |
| Normal Retina window | 1024×684 | 2× | 0 | 0 | 0 |
| Normal Retina window | 1280×800 | 2× | 0 | 0 | 0 |
| Normal Retina window | 1024×684 | 2× | 800 | 0 | 0 |
| Normal Retina window | 1024×684 | 2× | 1600 | 0 | 0 |

The normal-window comparisons use a fresh Vox resource cache per capture,
matching Brave's fresh isolated reference profile. The five earlier controlled
regressions retain their complete-response cache. This distinction matters for
lossy WebP: Chromium keeps the RGB generator created from an incomplete
response, while a generator created from a complete response can use YUV.
The tests preserve the original references and exercise both representations.
Wait two seconds after scrolling as well as after initial load, so newly visible
image tiles finish their final raster.

## Implemented behavior

- Supported HTML and image documents lay out at the native display density.
  CSS viewport sizes, media queries, computed styles and DOM geometry remain in
  CSS pixels. Projected layout lengths and retained fonts use device coordinates,
  preserving Brave's 1/128 CSS-pixel layout grid at 2×. An enclosing paint
  transform maps the resulting geometry back into the document viewport.
- Downloaded fonts use their compact cmap for glyph membership and fallback
  metrics. Projected and anonymous styles preserve the selected physical font
  cache after font-size setters have invalidated it.
- SVG images retain vectors and their exact intrinsic aspect ratio. Eligible
  root images share one Dawn recording with text, backgrounds, borders and
  images. Fully clipped leaves do not disable that recording. Effects, gradients
  and unsupported visible clips retain their ordinary replay path.
- Separate SVG compositor layers retain their own transparent background and
  device-pixel dimensions. Their fractional bounds survive until raster sizing;
  extra pixels in an enclosing CSS rectangle stay outside the raster surface.
  Non-scaling strokes, paint order and fractional fill/stroke opacity survive
  the shared and isolated recordings.
- The pinned Dawn Skia build uses Chromium's macOS text gamma configuration.
  Disabling the standalone A8 gamma adjustment fixes colored large text that
  crosses the distance-field glyph threshold.
- Image HTTP responses retain whether a usable header prefix arrived before
  completion. Streamed simple lossy WebP images keep their RGB generator for
  that response, including later offscreen painting. Complete cached bodies
  can use YUV. The decision follows response bytes and lifetime rather than a
  URL or display-scale heuristic. Native Fetch also honors `VOX_PROXY`.
- Static WebP painting preserves Chromium alpha premultiplication and ICC
  conversion. Fractional HSL background channels survive until rasterization.
- Root rasterization retains Chromium's tile dimensions, shared border
  ownership and two-dimensional MSAA classification. CSS viewport size remains
  separate from the compositor's device viewport size.
- Retained text preserves italic faces and Chromium font synthesis. List
  markers use the adjusted inline font ascent. Generic monospace selects
  Menlo, and unitless Chromium line heights truncate at layout precision.
- Explicit CSS transforms preserve rounded background geometry in local
  coordinates. Captures suppress pointer-dependent overlay scrollbars.

Focused regressions include `svg-image-non-scaling-stroke`,
`svg-shared-root-recording`, `svg-shared-empty-clip`,
`font-large-distance-field`, and the native-scale `isolated-svg-strokes`.
Each requires exact RGBA equality against its original Brave PNG.

Chromium's [viewport scaling implementation](https://chromium.googlesource.com/chromium/src/+/0c4572c29ed752832057a9b89b4e7c2252013992/content/renderer/render_widget.cc)
distinguishes native and emulated display scale. Its
[deferred image decoder](https://chromium.googlesource.com/chromium/src/+/155.0.8059.80/third_party/blink/renderer/platform/graphics/deferred_image_decoder.cc)
retains the representation chosen when the image generator was created.

## Reproduce a normal Retina viewport

Build the bundle, capture Brave on the test display away from the pointer,
and preserve device pixels when cropping Vox's browser chrome:

```sh
sh build-prod-browser.sh
python3 tools/capture_brave_reference.py \
  --url https://asgardpvp.com --out Build/asgard-brave-native.png \
  --width 1024 --height 684 --scale 2 --settle 2 \
  --proxy-server socks5h://127.0.0.1:1337 \
  --windowed --native-scale --window-position 0,25
capture_cache=$(mktemp -d /tmp/vox-asgard-cache.XXXXXX)
VOX_PROXY=socks5h://127.0.0.1:1337 LADYBIRD_CACHE_DIR="$capture_cache" \
  LADYBIRD_SCREENSHOT_SCALE=2 VOX_SCREENSHOT_NATIVE_LAYOUT=1 \
  LADYBIRD_SCREENSHOT_DELAY_SECONDS=2 \
  Build/v/Vox.app/Contents/MacOS/Vox \
  --window-width 1024 --window-height 768 \
  --screenshot Build/asgard-vox-window.png https://asgardpvp.com
rm -rf "$capture_cache"
sips --cropToHeightWidth 1368 2048 --cropOffset 120 0 \
  Build/asgard-vox-window.png --out Build/asgard-vox-native.png
python3 tools/check_pixel_equality.py \
  Build/asgard-brave-native.png Build/asgard-vox-native.png Build/asgard-diff.png
```

For scrolled comparisons, add `--scroll-y 800` or `--scroll-y 1600` to Brave's
capture and the matching `--screenshot-scroll-y` to Vox's capture. Actual CSS
viewport dimensions and scroll offsets must match. A stitched tall capture
cannot substitute for these scrolled viewports because fixed content belongs
to the visible viewport.

The equality command fails while any pixel differs. Normal interactive windows
select native layout automatically; the screenshot override above explicitly
requests the same layout instead of screenshot emulation.
