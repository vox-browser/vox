# Repository instructions

## Commits

- Commit each completed translation feature separately with a focused commit
  message. Do not combine unrelated translation slices in one commit.
- Include the feature's focused tests in the same commit as its implementation.
- Keep documentation-only and tooling-only changes in separate commits when
  they are independently reviewable.

## LibWeb V translation

- This repository (`~/code/vox2`) is the canonical LibWeb V translation workspace.
- Use `~/code/3rd/ladybird/Libraries/LibWeb` as the upstream source reference.
- Keep all translated V implementation code, tests, generated translation assets,
  and translation-specific documentation in this repository.
- Do not place V translation files in the Ladybird upstream checkout.
- Preserve working translated behavior when replacing generated placeholders;
  add focused tests for each completed translation slice.

## Build and run Ladybird V

- Build the native macOS bundle from this repository with:

  ```sh
  cd ~/code/vox2
  ./build_ladybird.sh
  ```

- `build_ladybird.sh` uses `V_BIN` when set, then `v` from `PATH`, and finally
  `~/code/v/v`. It writes `Build/v/Ladybird.app` and ad-hoc signs the bundle.
- Launch the browser with `open Build/v/Ladybird.app`, or pass a URL, an HTML
  file, or literal HTML directly to its executable:

  ```sh
  Build/v/Ladybird.app/Contents/MacOS/Ladybird https://example.com
  Build/v/Ladybird.app/Contents/MacOS/Ladybird ./page.html
  ```

- Run the non-windowed engine/JavaScript startup check with:

  ```sh
  Build/v/Ladybird.app/Contents/MacOS/Ladybird --headless-smoke
  ```

- Run all translation tests from this repository with `v test .`. When `v` is
  not on `PATH`, use `~/code/v/v test .`.
- The V bundle is independent of upstream Ladybird at
  `~/code/3rd/ladybird/Build/release/bin/Ladybird.app`.

## Screenshot conformance workflow

- Capture only the rendered document viewport from the native V browser (excluding
  its toolbar, status bar, and macOS title bar) with:

  ```sh
  ./capture_screenshot.sh SOURCE OUTPUT.png [WIDTH [HEIGHT]]
  ```

  The default viewport is 800x600. The script rebuilds a stale bundle, captures
  the native Cocoa content view without Screen Recording permission, accounts
  for Retina scale, crops the browser chrome, and writes a logical-pixel PNG. Set
  `SCREENSHOT_SETTLE_SECONDS` when a page needs longer than the default two
  seconds to settle.

- Compare canonical upstream screenshot inputs pixel by pixel with:

  ```sh
  ./compare_screenshots.sh
  ./compare_screenshots.sh inline-node ordered-list
  ```

  With no arguments the current smoke set is `inline-node`, `ordered-list`,
  `text-decorations`, `line-clamp-properties`, `canvas-text`, the three
  live-selection reftests (`selection-focus-between-text-controls`,
  `selection-insert-between-boundaries`, and `selection-moves-between-subtrees`),
  `empty-caret-with-placeholder`, and `caret-after-first-character`.
  A case name first resolves against upstream
  `Tests/LibWeb/Screenshot/{input,expected}`, then against `Tests/LibWeb/Ref/input`.
  For a reftest, the command follows its
  `<link rel="match">` or `<link rel="mismatch">` and captures both pages through
  the V browser. An input HTML path is also accepted. The command prints differing-pixel,
  maximum-channel-error, MAE, and RMSE metrics and writes `*.actual.png` plus an
  amplified `*.diff.png` heatmap under `Build/comparisons/`.
- Keep `svg-image-source-switch-same-size` pixel-exact when changing the compact
  script bridge or image invalidation. Script-visible `img.src` replacements
  must reach the live DOM, refresh the image model, and invalidate both layout
  and retained paint input even when the replacement has identical dimensions.
- Keep the SVG paint-server mutation reftests pixel-exact when changing the
  compact script bridge. Preserve tree-order identity when IDs collide, SVG
  attribute case and namespaces, script-created SVG children, `moveBefore()`
  ordering, retained animation end values, and paint-resource invalidation when
  an ID enters or leaves the document lookup map.
- Override the defaults with `LADYBIRD_SOURCE_DIR`, `V_BIN`, and
  `SCREENSHOT_OUTPUT_DIR`. The capture workflow is macOS-specific because it uses
  the Cocoa view snapshot helper and `sips`; the PNG diff tool itself is portable and
  can be run directly with `v run tools/pixel_diff.v EXPECTED ACTUAL DIFF`.

## Latest translated behavior

- Incremental HTML parsing retains encoding-sensitive bytes while scripts are
  deferred or the tokenizer is paused on a parser-blocking script. Late meta
  charset declarations can replace the streaming decoder before those bytes
  are consumed, and retained input is drained before implied EOF.
- SVG and MathML follow CSS Display unboxing rules: `display: contents`
  computes to `none` for CSS-box SVG roots, non-hoisting SVG elements, and all
  MathML elements. Nested SVG containers and text children keep `contents`,
  with `foreignObject` resetting the outermost-SVG boundary.
- Pseudo-elements generated by the document element are not document roots:
  they keep their own display type and resolve font-relative lengths through
  the originating root element. The browser bridge replays live selection and
  `Range.surroundContents()` mutations used by the upstream crash reftest.
- HTML image `x`/`y` geometry resolves accumulated paint state only after a
  committed layout box is found; disconnected or `display:none` images return
  zero without touching stale paint properties.
- `-webkit-font-smoothing` parses and inherits through computed style, reaches
  foreground text, text shadows, and `background-clip: text`, and selects the
  corresponding macOS Skia/CoreGraphics rasterization mode.
- Scripted boundary selections remain live when nodes are inserted between
  them, selection moves are replayed in order, and CSSOM selection-style
  mutations reach the final paint without retaining a stale highlight.
- Empty editable blocks, paragraphs, and inline elements size their caret from
  font ascent plus descent, cap it at line height, and center it in extra line
  leading. The compact browser bridge replays `Selection.collapse()` so the
  upstream placeholder reftest exercises a real caret on both sides.
- Parent child-boundary carets use the retained fragment of the adjacent text
  child, preferring the previous child's end before the next child's start.
  The compact browser attaches a focused HTML navigable before recording paint,
  so caret reftests exercise visible LTR, RTL, and vertical geometry.
- Dashed CSS calls now evaluate active `@function` definitions during arbitrary
  substitution. Function-local parameters, defaults, declarations, typed return
  syntax, inheritance, and resolved-value caching share guarded cycle state;
  property guards include function identity, arguments substitute before arity
  rejection, and custom-property dependencies retain access to the function
  registry.

## Translated module inventory

All 78 translated LibWeb packages and all 1,193 current module-owned C++
implementation units have audited V mappings. As of 2026-09-19, the module
translations contain 350,559 implementation V LOC and 71,422 test V LOC.
Physical LOC includes comments and blank lines. Root support code and browser
integration code are excluded. `Selection` includes `dom/selection.v`, and
`UIEvents` includes `dom/ui_events.v`.

| Module | Implementation V LOC | Module | Implementation V LOC |
| --- | ---: | --- | ---: |
| ARIA | 2,535 | Animations | 3,972 |
| Bindings | 2,675 | CSS | 104,527 |
| Clipboard | 973 | Compositor | 2,403 |
| Compression | 424 | ContentSecurityPolicy | 2,738 |
| CookieStore | 859 | CredentialManagement | 418 |
| Crypto (`webcrypto/`) | 4,472 | DOM | 36,534 |
| DOMURL | 754 | Editing | 8,515 |
| Encoding | 705 | EncryptedMediaExtensions | 572 |
| EntriesAPI | 44 | EventTiming | 153 |
| Fetch | 5,188 | FileAPI | 1,018 |
| Fullscreen | 93 | GPC | 16 |
| Gamepad | 760 | Geolocation | 416 |
| Geometry | 2,062 | HTML | 57,053 |
| HighResolutionTime | 442 | IndexedDB | 5,211 |
| Infra | 207 | Internals | 854 |
| IntersectionObserver | 569 | Layout | 43,283 |
| Loader | 1,921 | MathML | 411 |
| MediaCapabilitiesAPI | 676 | MediaCapture | 1,205 |
| MediaSourceExtensions | 357 | MimeSniff | 1,108 |
| MixedContent | 125 | NavigationTiming | 291 |
| NotificationsAPI | 290 | Page | 2,953 |
| Painting | 6,975 | PerformanceTimeline | 447 |
| PermissionsAPI | 239 | Platform | 1,750 |
| ReferrerPolicy | 239 | RequestIdleCallback | 59 |
| ResizeObserver | 420 | ResourceTiming | 338 |
| SRI | 156 | SVG | 5,184 |
| SecureContexts | 59 | Selection | 648 |
| Serial | 243 | ServiceWorker | 1,562 |
| Speech | 624 | StorageAPI | 444 |
| Streams | 6,290 | TrustedTypes | 756 |
| UIEvents | 1,359 | URLPattern | 1,632 |
| UserTiming | 119 | ViewTransition | 598 |
| WebAssembly | 2,065 | WebAudio | 2,649 |
| WebDriver | 3,447 | WebGL | 6,205 |
| WebIDL | 2,162 | WebLocks | 701 |
| WebSockets | 316 | WebVTT | 464 |
| WebXR | 312 | Worker | 81 |
| XHR | 1,131 | XLink | 13 |
| XML | 477 | XPath | 613 |
| **Total** | **350,559** |  |  |

`PORT_STATUS.md` is the canonical detailed inventory. It also records upstream
C++ file/LOC counts, per-module test LOC, status, and the counting conventions;
keep its figures synchronized when translated files change materially.
