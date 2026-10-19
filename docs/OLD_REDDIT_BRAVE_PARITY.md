# Old Reddit rendering against Brave

The signed production Vox renderer matches the authenticated frozen Brave
reference at **every pixel: 0 / 786,432 differences**. Both document viewports
are 1024×768 at device scale 1. The comparison includes the full viewport,
with exact RGBA equality and no tolerance or excluded regions.

![Brave on the left and Vox on the right](images/old-reddit-brave-vox.png)

[CPU instruction measurements](OLD_REDDIT_INSTRUCTIONS.md) record the
launch-through-capture comparison against Brave.

## Scope and reproduction

The reference is Brave 155.1.97.57 on macOS. The authenticated Brave DOM was
frozen, executable script elements removed, and its original document base URL
installed. Both browsers render that same HTML with its styles and resources.
This keeps changing post scores and timestamps out of the comparison. The
result establishes equality for this captured viewport, rather than general
Brave equivalence across live scripts, interactions, viewports, or platforms.

The native Cocoa document viewport is captured without browser chrome on the
test display away from the pointer. Its pixels are never replaced by the
reference. The saved side-by-side image contains both captures at their
original pixel dimensions.

Private account-bearing inputs and diagnostic artifacts remain under ignored,
mode-0700 `Build/reddit-parity/`. The canonical files are `frozen.html`,
`brave-frozen.png`, `vox-production.png`, `production.diff.png`,
`production.metrics.txt`, and `production-result.json`.

```sh
sh build-prod-browser.sh
./capture_screenshot.sh Build/reddit-parity/frozen.html \
  Build/reddit-parity/vox-production.png 1024 768
python3 tools/check_pixel_equality.py \
  Build/reddit-parity/brave-frozen.png \
  Build/reddit-parity/vox-production.png \
  Build/reddit-parity/production.diff.png \
  --result Build/reddit-parity/production-result.json
```

The gate exits nonzero for any differing RGBA pixel. Public, synthetic
regressions and Brave references are in
[`Tests/Browser/Brave`](../Tests/Browser/Brave/README.md). The older
`old-reddit-worldnews` fixture remains a separate archived Ladybird comparison;
its reference and allowances have not changed.

## Rendering changes

All native browser documents use the Chromium compatibility policy, including
local files and saved pages regardless of their base URL. The changes cover:

- Chromium font keyword sizes, fractional font metrics and glyph advances,
  normal line heights, font smoothing, and sRGB text compositing.
- Typed CSS length truncation, cumulative shaped-item advance rounding,
  fitting and wrapping, and shared Latin shaping across word boundaries and
  LTR directional isolates.
- Line and inline-box paint origins at fractional offsets, outside list marker
  geometry, default form fonts, placeholders, and explicit empty input labels.
- Image request initialization, orientation, WebP YUV decoding, CPU plane
  resizing, GPU upload dimensions, and color conversion.
- Analytic rounded borders, opaque background and shadow overlap, GPU rounded
  image clips, preceding repeated-image tiles, and negative half-pixel sprite
  origins. These preserve unscaled sprite texels and rounded corner coverage.
- Native overlay scrollbar visibility and fading after interaction.

Chromium-compatible shadows, image sampling and rounded shapes use an isolated,
pinned Skia 155 Metal backend. Its C ABI exchanges pixels and plain values;
hidden Skia symbols keep it separate from LibWeb's existing Skia library.
The verified dependency is cached under `Build/deps/skia-brave`; see
[`tools/build_mac_graphite.py`](../tools/build_mac_graphite.py).

Relevant Chromium sources include
[box background bleed avoidance](https://chromium.googlesource.com/chromium/src/+/155.0.8059.80/third_party/blink/renderer/core/paint/box_decoration_data.cc),
[border painting](https://chromium.googlesource.com/chromium/src/+/155.0.8059.80/third_party/blink/renderer/core/paint/box_border_painter.cc),
[inline background painting](https://chromium.googlesource.com/chromium/src/+/155.0.8059.80/third_party/blink/renderer/core/paint/inline_box_fragment_painter.cc),
and [image upload sizing](https://chromium.googlesource.com/chromium/src/+/155.0.8059.80/cc/tiles/gpu_image_decode_cache.cc).

## Authentication

The account owner's Brave Reddit cookies were explicitly imported through an
isolated Brave profile. The original profile remains unchanged. The frozen
reference and native capture contain the authenticated page. Cookie values,
the cookie database and private HTML are excluded from commits. A fresh live
check on 2026-10-16 returned a block page in isolated Brave and HTTP 403
outside the browser. Current live login could therefore not be revalidated;
this does not change the authenticated frozen comparison.

To refresh the imported session after signing in through Brave:

```sh
python3 tools/import_brave_reddit_session.py
open -n Build/v/Vox.app --args https://old.reddit.com/r/worldnews/
```

The importer writes `~/Library/Application Support/Vox/imported-cookies.txt`
with mode 0600. It prints no cookie values and accesses no account password.
Temporary import profiles are removed after use. The runtime reads this
Netscape-format jar on each request. `VOX_COOKIE_FILE` selects another jar;
an explicitly empty value disables import for that process.

Imported cookies retain domain/host-only, path, expiry, Secure and HttpOnly
attributes. Netscape files cannot retain SameSite or partition keys, so
partitioned cookies are excluded and imported cookies are sent only in a
same-site context. This read-only import does not implement a complete
persistent cookie store or replace DOM cookie APIs.

## SOCKS5 access

Set the proxy on each new Vox process, including launches through macOS
Launch Services:

```sh
open -n Build/v/Vox.app --env VOX_PROXY=socks5h://127.0.0.1:1337 \
  --args https://old.reddit.com/
open -n Build/v/Vox.app --env VOX_PROXY=socks5h://127.0.0.1:1337 \
  --args https://boards.4chan.org/pol/
```

`VOX_PROXY` overrides ambient HTTP/HTTPS/ALL proxy variables. Both `socks5`
and `socks5h` send destination hostnames to the proxy. `NO_PROXY`/`no_proxy`
retain host, domain, port and wildcard exclusions. Invalid or unavailable
proxies fail the request instead of opening a direct connection. Proxy
tunnels retain certificate and hostname validation and currently use HTTP/1.1.

Capture Brave with the same imported session and proxy in a temporary profile:

```sh
python3 tools/capture_brave_reference.py \
  --url https://old.reddit.com/ \
  --out Build/reddit-parity/brave-socks-live.png \
  --width 1024 --height 768 --scale 1 \
  --proxy-server socks5h://127.0.0.1:1337 \
  --cookie-file "$HOME/Library/Application Support/Vox/imported-cookies.txt" \
  --metadata Build/reddit-parity/brave-socks-live.json
```

On 2026-10-17, Brave successfully loaded example.com through this SOCKS5
proxy, but old.reddit.com displayed "You've been blocked by network security"
with the imported Reddit cookies. A proxied HTTP request likewise returned
403. This prevents a fresh authenticated live-page comparison; the frozen
authenticated comparison remains the rendering regression gate.

## Validation

The signed production capture passes the exact-pixel gate. All thirteen public
Brave fixtures also pass exact RGBA comparisons, including fonts, backgrounds,
WebP images, shadows, text shaping, markers, and bitmap sprites. Relevant
layout and geometry checks pass, including focused ownership runs with
`-gc none`. The native Skia clip checks, bundle signature verification and
headless startup smoke pass. All eleven default screenshot smoke comparisons
pass under their existing acceptance rules.

The browser continues to use JavaScriptCore. This screenshot result does not
establish full LibJS parity. Translucent-group shadow compositing remains a
separate diagnostic with five one-channel differences of 1; it is outside the
captured page and the opaque-shadow fixture.
