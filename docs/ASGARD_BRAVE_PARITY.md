# AsgardPvP rendering against Brave

The five controlled viewport comparisons below are **pixel-exact**. Normal
Retina-window parity remains unfinished. Comparisons require identical RGBA
pixels, without a tolerance or excluded regions. Browser chrome is cropped;
the rendered document viewport is compared at the same size and raster scale.

The reference browser used on 2026-10-18 and rechecked on 2026-10-19 was Brave 155.1.97.59 on macOS.
The 1280×800 reference was rechecked on 2026-10-20; it still changed zero pixels.
Both browsers reached `https://asgardpvp.com/` through the SOCKS5 proxy on
`127.0.0.1:1337`. Repeating the 1280×800 Brave capture changed zero pixels.

## Measured results

These are document viewport captures from the rebuilt native bundle. A 2×
viewport has two device pixels per CSS pixel in each axis.

| Viewport | Scale | Scroll Y | Differing pixels | Maximum channel error |
| --- | --- | --- | --- | --- |
| 800×600 | 1× | 0 | 0 | 0 |
| 1280×800 | 1× | 0 | 0 | 0 |
| 1024×684 | 2× | 0 | 0 | 0 |
| 1280×800 | 1× | 800 | 0 | 0 |
| 1280×800 | 1× | 1600 | 0 | 0 |

The signed native bundle built on 2026-10-21 passes all five comparisons.
The previously failing wider logo is exact after sharing its drawing operations
with the surrounding root tile. Focused shared-recording tests pass with Boehm
and `-gc none`; native startup also passes. The original Brave reference PNGs
are unchanged.

These references use headless Brave's emulated device scale. Emulating 2× on a
1× host does not reproduce the layout precision of a normal 2× window; see the
remaining work below.
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
- Supported root SVG tiles share one recording with text, backgrounds, borders
  and images through pinned Dawn/Metal. Flex and grid items paint atomically in
  foreground order. Fully clipped leaves, such as hidden accessible controls,
  do not disable this recording; effect boundaries and visible unsupported clips
  retain their established replay path.

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

The equality command fails while any pixel differs.

## Remaining work

Normal Retina windows still require layout in device pixels. At 2×, Brave
exports CSS coordinates on a 1/128-pixel grid, while a 2× emulated screenshot
on a 1× host retains 1/64-pixel layout. The native browser currently uses the
latter precision. The difference is measurable in DOM rectangles and font
placement, and the normal-window result is not covered by the exact table.
Chromium distinguishes the original display scale from the emulated scale
when sizing its layout viewport; see its
[viewport scaling implementation](https://chromium.googlesource.com/chromium/src/+/0c4572c29ed752832057a9b89b4e7c2252013992/content/renderer/render_widget.cc).

The comparison must also use one color space. Windowed Brave screenshots on
this display carry a Display P3 profile; headless references and Vox's document
captures use sRGB. Normal-window diagnostics force Brave's output profile to
sRGB before comparing pixels.
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
