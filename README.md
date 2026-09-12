# LibWeb V translation

This repository at `~/code/vox2` is the canonical workspace for the V
translation of Ladybird's LibWeb. The upstream C++ reference is
`~/code/3rd/ladybird/Libraries/LibWeb`.

All translated V implementation code, tests, generated translation assets, and
translation-specific documentation belong in this repository. See
[`PORT_STATUS.md`](PORT_STATUS.md) for the module inventory and LOC table, and
[`ROOT_SUPPORT.md`](ROOT_SUPPORT.md) for the root support-file mapping.

## Translation footprint

As of 2026-09-12, tracked V sources contain **340,625 implementation LOC** and
**65,932 test LOC**. The current module-owned translation subset contains
**329,734 implementation LOC** and **62,094 test LOC**; the difference is root
support, browser integration, and translation tooling. See the canonical
current table in [`PORT_STATUS.md`](PORT_STATUS.md).

The counts below preserve the 2026-08-29 checkpoint for historical comparison.
They are physical lines (`wc -l`), including comments and blank lines. Upstream
counts include each module's subdirectories.

| Module | Upstream `.cpp` LOC | Upstream `.cpp` + `.h` LOC | V implementation LOC | V test LOC |
| --- | ---: | ---: | ---: | ---: |
| `ARIA` | 1,876 | 2,623 | 2,523 | 354 |
| `Animations` | 4,381 | 5,457 | 2,217 | 389 |
| `Bindings` | 1,718 | 2,423 | 1,639 | 488 |
| `CSS` | 66,305 | 84,658 | 90,675 | 3,594 |
| `Clipboard` | 892 | 1,088 | 948 | 332 |
| `Compression` | 359 | 467 | 322 | 135 |
| `ContentSecurityPolicy` | 4,653 | 6,042 | 2,404 | 389 |
| `CookieStore` | 900 | 1,036 | 997 | 392 |
| `CredentialManagement` | 369 | 647 | 400 | 293 |
| `Crypto` | 13,297 | 14,720 | 2,303 | 879 |
| `DOM` | 26,465 | 33,101 | 32,188 | 1,494 |
| `DOMURL` | 1,016 | 1,257 | 932 | 270 |
| `Editing` | 7,980 | 8,277 | 2,019 | 660 |
| `Encoding` | 438 | 609 | 668 | 235 |
| `EncryptedMediaExtensions` | 544 | 767 | 572 | 329 |
| `EntriesAPI` | 55 | 94 | 44 | 32 |
| `EventTiming` | 131 | 204 | 170 | 93 |
| `Fetch` | 7,787 | 10,319 | 3,194 | 876 |
| `FileAPI` | 1,359 | 1,750 | 943 | 448 |
| `Fullscreen` | 0 | 0 | 93 | 177 |
| `GPC` | 21 | 40 | 16 | 13 |
| `Gamepad` | 1,382 | 1,796 | 681 | 210 |
| `Geolocation` | 511 | 689 | 391 | 174 |
| `Geometry` | 2,157 | 2,725 | 1,962 | 952 |
| `HTML` | 73,434 | 93,439 | 54,896 | 10,966 |
| `HighResolutionTime` | 521 | 656 | 362 | 181 |
| `IndexedDB` | 6,449 | 8,098 | 2,362 | 523 |
| `Infra` | 405 | 556 | 193 | 61 |
| `Internals` | 951 | 1,287 | 826 | 220 |
| `IntersectionObserver` | 445 | 661 | 376 | 186 |
| `Layout` | 19,592 | 23,711 | 27,672 | 8,384 |
| `Loader` | 887 | 1,289 | 830 | 292 |
| `MathML` | 292 | 469 | 361 | 75 |
| `MediaCapabilitiesAPI` | 247 | 386 | 369 | 99 |
| `MediaSourceExtensions` | 413 | 695 | 357 | 110 |
| `MimeSniff` | 1,357 | 1,530 | 1,035 | 269 |
| `MixedContent` | 121 | 150 | 125 | 105 |
| `NavigationTiming` | 104 | 252 | 264 | 42 |
| `NotificationsAPI` | 249 | 388 | 278 | 68 |
| `Page` | 4,298 | 5,338 | 1,533 | 317 |
| `Painting` | 10,038 | 13,879 | 4,265 | 825 |
| `PerformanceTimeline` | 391 | 672 | 417 | 130 |
| `PermissionsPolicy` | 98 | 152 | 79 | 21 |
| `Platform` | 415 | 603 | 1,014 | 61 |
| `ReferrerPolicy` | 298 | 358 | 239 | 123 |
| `RequestIdleCallback` | 55 | 106 | 36 | 10 |
| `ResizeObserver` | 376 | 587 | 238 | 89 |
| `ResourceTiming` | 340 | 431 | 317 | 71 |
| `SRI` | 191 | 217 | 147 | 95 |
| `SVG` | 9,570 | 13,735 | 3,561 | 726 |
| `SecureContexts` | 88 | 112 | 63 | 13 |
| `Selection` | 744 | 837 | 569 | 96 |
| `Serial` | 381 | 565 | 231 | 33 |
| `ServiceWorker` | 1,365 | 1,842 | 842 | 248 |
| `Speech` | 504 | 1,071 | 596 | 111 |
| `StorageAPI` | 381 | 769 | 342 | 146 |
| `Streams` | 8,784 | 10,923 | 4,683 | 918 |
| `TrustedTypes` | 1,108 | 1,472 | 722 | 168 |
| `UIEvents` | 1,557 | 2,712 | 1,270 | 252 |
| `URLPattern` | 148 | 210 | 300 | 41 |
| `UserTiming` | 164 | 278 | 89 | 29 |
| `ViewTransition` | 1,046 | 1,217 | 567 | 319 |
| `WebAssembly` | 2,157 | 2,606 | 740 | 245 |
| `WebAudio` | 3,649 | 5,305 | 1,660 | 298 |
| `WebDriver` | 5,013 | 6,063 | 2,091 | 423 |
| `WebGL` | 7,163 | 8,997 | 3,006 | 288 |
| `WebIDL` | 2,110 | 3,055 | 1,139 | 279 |
| `WebSockets` | 429 | 515 | 285 | 100 |
| `WebVTT` | 326 | 510 | 445 | 221 |
| `WebXR` | 409 | 565 | 200 | 41 |
| `Worker` | 47 | 87 | 81 | 33 |
| `XHR` | 1,706 | 2,179 | 964 | 274 |
| `XLink` | 16 | 45 | 13 | 10 |
| `XML` | 534 | 617 | 244 | 83 |
| `XPath` | 438 | 626 | 407 | 83 |
| **Total** | **316,400** | **403,612** | **263,954** | **41,167** |

Build the optimized V-native translated-engine browser as a macOS application
bundle with:

```sh
./build-prod-browser.sh
open Build/v/Ladybird.app
```

The production builder uses `-enable-globals -prod -gc none`, integrates the
upstream Skia text bridge when its release dependencies are available, writes
`Build/v/Ladybird.app`, and ad-hoc signs the bundle. `build_ladybird.sh` remains
as a compatibility alias for existing tooling.

The application provides a native single-tab browser chrome with back/forward,
reload, home, an editable address/search field, link navigation, loading and
console status, and scrolling. HTTP(S), local files, external stylesheets, and
classic scripts feed the translated HTML, DOM, CSS, Layout, hit-testing,
history, and paint-command pipeline. On macOS, JavaScriptCore supplies actual
ECMAScript evaluation at the translated Bindings host boundary; common
`document`, element mutation, location, events, timers, and console operations
are bridged back into the translated DOM before reflow.

On macOS, production layout uses Arial/Helvetica-compatible metrics to match
the native Cocoa painter. Set `LADYBIRD_BROWSER_FONT` to another TrueType font
path to override it; `LADYBIRD_LAYOUT_TEST_FONT` continues to take precedence
for deterministic layout tests.

Pass a URL, local HTML path, or raw HTML to the bundle executable to open it. A
small non-windowed build/startup check is available as:

```sh
Build/v/Ladybird.app/Contents/MacOS/Ladybird --headless-smoke
```

Compare the V browser against checked-in upstream C++ screenshots of the
confirmed Example Domain, Hacker News, and old Reddit pages with:

```sh
./compare_site_pixels.sh
```

The fixtures, reference provenance, metric ceilings, and per-site invocation
are documented in [`pixel_tests/README.md`](pixel_tests/README.md).

This bundle is distinct from `~/code/3rd/ladybird/Build/.../Ladybird.app`, which
is the upstream C++ application. The V-native application does not yet provide
the full generated Web-IDL JavaScript surface, multi-process isolation, tabs,
downloads, media playback, or persistent browser profiles.

Run the full translation test suite with:

```sh
v -enable-globals test .
```
