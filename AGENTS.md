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
  `text-decorations`, and `line-clamp-properties`. A case name first resolves
  against upstream `Tests/LibWeb/Screenshot/{input,expected}`, then against
  `Tests/LibWeb/Ref/input`. For a reftest, the command follows its
  `<link rel="match">` or `<link rel="mismatch">` and captures both pages through
  the V browser. An input HTML path is also accepted. The command prints differing-pixel,
  maximum-channel-error, MAE, and RMSE metrics and writes `*.actual.png` plus an
  amplified `*.diff.png` heatmap under `Build/comparisons/`.
- Override the defaults with `LADYBIRD_SOURCE_DIR`, `V_BIN`, and
  `SCREENSHOT_OUTPUT_DIR`. The capture workflow is macOS-specific because it uses
  the Cocoa view snapshot helper and `sips`; the PNG diff tool itself is portable and
  can be run directly with `v run tools/pixel_diff.v EXPECTED ACTUAL DIFF`.

## Translated module inventory

All 78 translated LibWeb packages and all 1,193 current module-owned C++
implementation units have audited V mappings. As of 2026-09-19, the module
translations contain 348,846 implementation V LOC and 70,476 test V LOC.
Physical LOC includes comments and blank lines. Root support code and browser
integration code are excluded. `Selection` includes `dom/selection.v`, and
`UIEvents` includes `dom/ui_events.v`.

| Module | Implementation V LOC | Module | Implementation V LOC |
| --- | ---: | --- | ---: |
| ARIA | 2,535 | Animations | 3,972 |
| Bindings | 2,675 | CSS | 103,995 |
| Clipboard | 973 | Compositor | 2,403 |
| Compression | 424 | ContentSecurityPolicy | 2,738 |
| CookieStore | 859 | CredentialManagement | 418 |
| Crypto (`webcrypto/`) | 4,472 | DOM | 36,256 |
| DOMURL | 754 | Editing | 8,510 |
| Encoding | 705 | EncryptedMediaExtensions | 572 |
| EntriesAPI | 44 | EventTiming | 153 |
| Fetch | 5,188 | FileAPI | 1,018 |
| Fullscreen | 93 | GPC | 16 |
| Gamepad | 760 | Geolocation | 416 |
| Geometry | 2,062 | HTML | 56,655 |
| HighResolutionTime | 442 | IndexedDB | 5,211 |
| Infra | 207 | Internals | 854 |
| IntersectionObserver | 569 | Layout | 43,043 |
| Loader | 1,921 | MathML | 411 |
| MediaCapabilitiesAPI | 676 | MediaCapture | 1,205 |
| MediaSourceExtensions | 357 | MimeSniff | 1,108 |
| MixedContent | 125 | NavigationTiming | 291 |
| NotificationsAPI | 290 | Page | 2,717 |
| Painting | 6,968 | PerformanceTimeline | 447 |
| PermissionsAPI | 239 | Platform | 1,750 |
| ReferrerPolicy | 239 | RequestIdleCallback | 59 |
| ResizeObserver | 420 | ResourceTiming | 338 |
| SRI | 156 | SVG | 5,167 |
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
| **Total** | **348,846** |  |  |

`PORT_STATUS.md` is the canonical detailed inventory. It also records upstream
C++ file/LOC counts, per-module test LOC, status, and the counting conventions;
keep its figures synchronized when translated files change materially.
