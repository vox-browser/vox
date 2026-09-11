# Repository instructions

## Commits

- Commit each completed translation feature separately with a focused commit
  message. Do not combine unrelated translation slices in one commit.
- Include the feature's focused tests in the same commit as its implementation.
- Keep documentation-only and tooling-only changes in separate commits when
  they are independently reviewable.

## LibWeb V translation

- This repository (`~/code/libweb_v`) is the canonical LibWeb V translation workspace.
- Use `~/code/3rd/ladybird/Libraries/LibWeb` as the upstream source reference.
- Keep all translated V implementation code, tests, generated translation assets,
  and translation-specific documentation in this repository.
- Do not place V translation files in the Ladybird upstream checkout.
- Preserve working translated behavior when replacing generated placeholders;
  add focused tests for each completed translation slice.

## Build and run Ladybird V

- Build the native macOS bundle from this repository with:

  ```sh
  cd ~/code/libweb_v
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

  With no arguments the current smoke set is `inline-node`, `ordered-list`, and
  `text-decorations`. A case name resolves against upstream
  `Tests/LibWeb/Screenshot/{input,expected}`; an input HTML path is also accepted.
  The command prints differing-pixel, maximum-channel-error, MAE, and RMSE metrics
  and writes `*.actual.png` plus an amplified `*.diff.png` heatmap under
  `Build/comparisons/`.
- Override the defaults with `LADYBIRD_SOURCE_DIR`, `V_BIN`, and
  `SCREENSHOT_OUTPUT_DIR`. The capture workflow is macOS-specific because it uses
  the Cocoa view snapshot helper and `sips`; the PNG diff tool itself is portable and
  can be run directly with `v run tools/pixel_diff.v EXPECTED ACTUAL DIFF`.

## Translated module inventory

All 75 of 75 upstream LibWeb module directories and all 1,147 module-owned C++
implementation units have audited V mappings. As of 2026-08-17, the module
translations contain 222,554 implementation V LOC and 33,406 test V LOC.
Physical LOC includes comments and blank lines. Root support code and browser
integration code are excluded. `Selection` includes `dom/selection.v`, and
`UIEvents` includes `dom/ui_events.v`.

| Module | Implementation V LOC | Module | Implementation V LOC |
| --- | ---: | --- | ---: |
| ARIA | 2,523 | Animations | 2,217 |
| Bindings | 1,639 | CSS | 86,672 |
| Clipboard | 948 | Compression | 322 |
| ContentSecurityPolicy | 2,404 | CookieStore | 997 |
| CredentialManagement | 400 | Crypto (`webcrypto/`) | 2,303 |
| DOM | 32,116 | DOMURL | 932 |
| Editing | 2,019 | Encoding | 668 |
| EncryptedMediaExtensions | 572 | EntriesAPI | 44 |
| EventTiming | 170 | Fetch | 3,194 |
| FileAPI | 943 | Fullscreen | 93 |
| GPC | 16 | Gamepad | 681 |
| Geolocation | 391 | Geometry | 1,962 |
| HTML | 36,891 | HighResolutionTime | 362 |
| IndexedDB | 2,362 | Infra | 193 |
| Internals | 826 | IntersectionObserver | 376 |
| Layout | 5,802 | Loader | 830 |
| MathML | 361 | MediaCapabilitiesAPI | 369 |
| MediaSourceExtensions | 357 | MimeSniff | 1,035 |
| MixedContent | 125 | NavigationTiming | 264 |
| NotificationsAPI | 278 | Page | 1,533 |
| Painting | 3,472 | PerformanceTimeline | 417 |
| PermissionsPolicy | 79 | Platform | 394 |
| ReferrerPolicy | 239 | RequestIdleCallback | 36 |
| ResizeObserver | 238 | ResourceTiming | 317 |
| SRI | 147 | SVG | 2,543 |
| SecureContexts | 63 | Selection | 569 |
| Serial | 231 | ServiceWorker | 842 |
| Speech | 596 | StorageAPI | 342 |
| Streams | 2,640 | TrustedTypes | 722 |
| UIEvents | 1,270 | URLPattern | 300 |
| UserTiming | 89 | ViewTransition | 567 |
| WebAssembly | 740 | WebAudio | 1,660 |
| WebDriver | 2,091 | WebGL | 1,982 |
| WebIDL | 1,139 | WebSockets | 285 |
| WebVTT | 445 | WebXR | 200 |
| Worker | 81 | XHR | 964 |
| XLink | 13 | XML | 244 |
| XPath | 407 | **Total** | **222,554** |

`PORT_STATUS.md` is the canonical detailed inventory. It also records upstream
C++ file/LOC counts, per-module test LOC, status, and the counting conventions;
keep its figures synchronized when translated files change materially.
