# Vox app icon

`Vox.png` is the 1024×1024 source artwork, generated with the built-in imagegen
tool and resized with `sips`, preserving its transparent corners. `Vox.icns`
contains the standard macOS icon representations from 16×16 through 1024×1024.

After replacing the source artwork, regenerate the icon on macOS:

```sh
./tools/build_app_icon.sh
```

`./build-prod-browser.sh` copies `Vox.icns` into
`Build/v/Vox.app/Contents/Resources/` before signing the app. The bundle's
`CFBundleIconFile` references that resource.

## Generation prompt

```text
Use case: logo-brand
Asset type: production macOS application icon for the Vox web browser, square 1024 by 1024 PNG.
Primary request: Create an original polished app logo made from exactly the three letters "Vox" (uppercase V, lowercase o, lowercase x), in that order, on one line. All three letters are the main mark, very clear and immediately readable.
Style/medium: minimal, bold custom geometric typography, precise smooth edges, strong silhouette, balanced negative space. Modern understated macOS app icon quality.
Composition/framing: one centered icon only, straight-on view. A rounded-square macOS icon tile with transparent exterior corners and a modest even transparent safety margin around the tile. The three-letter wordmark is large and optically centered within the tile, with substantial stroke weight, enough separation to read each letter, and comfortable interior padding. Make the wordmark occupy about three quarters of the tile width.
Constraints: high contrast between letters and tile, legible when reduced to 32 pixels, simple uncluttered design, just one icon. Render the exact text "Vox" once. The letters are V, o, x. No other text, no slogan, no additional symbol, no browser globe or compass, no sheet of variants, no mockup, no perspective, no watermark. Genuinely transparent pixels outside the rounded tile.
```
