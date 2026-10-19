# AsgardPvP rendering against Brave

The live site is **not yet pixel-exact**. Comparisons require identical RGBA
pixels, without a tolerance or excluded regions. Browser chrome is cropped;
the rendered document viewport is compared at the same size and device scale.

The reference browser used on 2026-10-18 and rechecked on 2026-10-19 was Brave 155.1.97.59 on macOS.
Both browsers reached `https://asgardpvp.com/` through the SOCKS5 proxy on
`127.0.0.1:1337`. Repeating the 1280×800 Brave capture changed zero pixels.

## Measured results

These are document viewport captures from the rebuilt native bundle. A 2×
viewport has two device pixels per CSS pixel in each axis.

| Viewport | Scale | Scroll Y | Differing pixels | Maximum channel error |
| --- | --- | --- | --- | --- |
| 800×600 | 1× | 0 | 0 | 0 |
| 1280×800 | 1× | 0 | 2 | 6 |
| 1024×684 | 2× | 0 | 0 | 0 |
| 1280×800 | 1× | 800 | 0 | 0 |
| 1280×800 | 1× | 1600 | 0 | 0 |

The two wider-viewport discrepancies are in the logo; they still fail exact
equality. The same-size SVG source replacement reftest passes with zero differing
pixels. The original inputs for 22 focused Brave rendering fixtures passed in the
isolated validation checkout. The new `webp-root-raster-tiles`,
`svg-image-raster-origin`, `msaa-tile-columns`, and
`transformed-rounded-background` fixtures also pass exact comparisons. This does
not certify concurrent fixture edits in the main checkout.
Native clipping, compositing, glyph-cache, shape-backdrop, and tiled-image
checks pass. Focused V checks also passed with Boehm and with `-gc none`.

## Implemented behavior

- SVG image requests retain vectors and their exact intrinsic aspect ratio.
  Fractional SVG containers survive layout before destination snapping.
- Eligible SVG images paint their paths in one GPU recording, including
  non-scaling strokes, paint order, and fractional stroke/fill opacity.
  Effects and inner clips retain the ordinary replay path. Separate compositor
  layers use their own transparent background.
- Retained text preserves italic faces and Chromium font synthesis. List
  markers use the adjusted inline font ascent. Generic monospace selects
  Menlo, and unitless Chromium line heights truncate at layout precision.
- Tagged static WebP painting uses Chromium alpha premultiplication and ICC
  conversion. Fractional HSL background channels survive until rasterization.
- Captures suppress pointer-dependent overlay scrollbars.
- Root rasterization retains Chromium's tile width, height, shared border
  ownership, and two-dimensional MSAA classification. The raster scale remains
  separate from the compositor's device viewport size.
- SVG circles and ellipses retain fractional user units. SVG image embedding
  transforms and non-scaling strokes remain separate; fixed layers include their
  empty container bounds when choosing a raster surface.
- Explicit CSS transforms, including identity transforms, preserve rounded
  background geometry in local coordinates.

The synthetic `svg-image-non-scaling-stroke` fixture includes adjacent flag
fills/strokes, fractional intrinsic image sizing, a distant image, and a
fractional stroke opacity. Its original Brave reference is pixel-exact.

## Reproduce the first viewport

```sh
sh build-prod-browser.sh
python3 tools/capture_brave_reference.py \
  --url https://asgardpvp.com --out Build/asgard-brave.png \
  --width 1280 --height 800 --scale 1 --settle 2 \
  --proxy-server socks5h://127.0.0.1:1337
VOX_PROXY=socks5h://127.0.0.1:1337 \
  ./capture_screenshot.sh https://asgardpvp.com Build/asgard-vox.png 1280 800
python3 tools/check_pixel_equality.py \
  Build/asgard-brave.png Build/asgard-vox.png Build/asgard-diff.png
```

The equality command intentionally fails while any pixel differs.

## Remaining work

The SVG logo retains two GPU edge differences at 1280×800. Replaying only the
logo's exported path geometry reproduces differences, while replaying Brave's
surrounding drawing operations changes the result even with identical path
coordinates. Shared GPU recording and shader behavior remain under investigation;
the experimental recording path is not enabled in the production app.

Lossy WebP representation also depends on the decoder's lifetime. Blink retains
RGB when its first decoding generator was created before the complete response
arrived; a complete response may use YUV. See
[Chromium's deferred decoder](https://chromium.googlesource.com/chromium/src/+/155.0.8059.80/third_party/blink/renderer/platform/graphics/deferred_image_decoder.cc).
Selecting RGBA merely because a resource has an HTTP URL regresses the images
below the fold. That experiment was reverted; network incremental-decoding
parity remains open.

A stitched tall capture is not a substitute for a scrolled viewport comparison:
its overridden layout viewport can place fixed content outside every native
window strip. Check actual viewport sizes and scroll offsets independently.
