# LibWeb V translation inventory

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb`

Translation workspace: `~/code/libweb_v`
Audited: 2026-08-17

Every upstream module now has a complete audited V translation. No partially
translated or wholly untranslated module remains.

`Complete` means every upstream `.cpp` unit has an audited V implementation
mapping. `Present` means translated module code exists but its full upstream
coverage has not yet been audited. `Untranslated` means no module translation
was found. There are no `Present` or `Untranslated` modules.

LOC is physical line count (`wc -l`), including comments and blank lines.
Implementation and test V counts are disjoint. `Selection` includes its shared
`dom/selection.v` implementation, and `UIEvents` includes its shared
`dom/ui_events.v` implementation. Root support and non-LibWeb support modules
are documented separately in `ROOT_SUPPORT.md` and are not included below.
The upstream `Crypto` module maps to the `webcrypto/` V package so it can use
V's standard `crypto.*` modules without shadowing that namespace.
The IDL-only `Fullscreen` package delegates its state machine to the shared
translated DOM implementation.

Inventory reconciliation covers all 75 of 75 upstream module directories and
all 1,147 of 1,147 module-owned `.cpp` implementation units. The four
root-level LibWeb `.cpp` support units are mapped separately in
`ROOT_SUPPORT.md`.

| Upstream module | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `ARIA` | 6 | 1,876 | 2,523 | 354 | Complete |
| `Animations` | 10 | 4,381 | 2,217 | 389 | Complete |
| `Bindings` | 9 | 1,718 | 1,639 | 488 | Complete |
| `CSS` | 212 | 66,305 | 86,672 | 3,018 | Complete |
| `Clipboard` | 4 | 892 | 948 | 332 | Complete |
| `Compression` | 2 | 359 | 322 | 135 | Complete |
| `ContentSecurityPolicy` | 37 | 4,653 | 2,404 | 389 | Complete |
| `CookieStore` | 2 | 900 | 997 | 392 | Complete |
| `CredentialManagement` | 6 | 369 | 400 | 293 | Complete |
| `Crypto` | 6 | 13,297 | 2,303 | 879 | Complete |
| `DOM` | 57 | 26,465 | 32,110 | 1,494 | Complete |
| `DOMURL` | 4 | 1,016 | 932 | 270 | Complete |
| `Editing` | 4 | 7,980 | 2,019 | 660 | Complete |
| `Encoding` | 4 | 438 | 668 | 235 | Complete |
| `EncryptedMediaExtensions` | 3 | 544 | 572 | 329 | Complete |
| `EntriesAPI` | 1 | 55 | 44 | 32 | Complete |
| `EventTiming` | 1 | 131 | 170 | 93 | Complete |
| `Fetch` | 32 | 7,787 | 3,194 | 876 | Complete |
| `FileAPI` | 6 | 1,359 | 943 | 448 | Complete |
| `Fullscreen` | 0 | 0 | 93 | 177 | Complete |
| `GPC` | 1 | 21 | 16 | 13 | Complete |
| `Gamepad` | 6 | 1,382 | 681 | 210 | Complete |
| `Geolocation` | 4 | 511 | 391 | 174 | Complete |
| `Geometry` | 8 | 2,157 | 1,962 | 952 | Complete |
| `HTML` | 261 | 73,434 | 36,891 | 7,611 | Complete |
| `HighResolutionTime` | 2 | 521 | 362 | 181 | Complete |
| `IndexedDB` | 18 | 6,449 | 2,362 | 523 | Complete |
| `Infra` | 3 | 405 | 193 | 61 | Complete |
| `Internals` | 7 | 951 | 826 | 220 | Complete |
| `IntersectionObserver` | 2 | 445 | 376 | 186 | Complete |
| `Layout` | 50 | 19,592 | 5,418 | 3,971 | Complete |
| `Loader` | 5 | 887 | 830 | 292 | Complete |
| `MathML` | 5 | 292 | 361 | 75 | Complete |
| `MediaCapabilitiesAPI` | 1 | 247 | 369 | 99 | Complete |
| `MediaSourceExtensions` | 8 | 413 | 357 | 110 | Complete |
| `MimeSniff` | 2 | 1,357 | 1,035 | 269 | Complete |
| `MixedContent` | 1 | 121 | 125 | 105 | Complete |
| `NavigationTiming` | 3 | 104 | 264 | 42 | Complete |
| `NotificationsAPI` | 1 | 249 | 278 | 68 | Complete |
| `Page` | 7 | 4,298 | 1,533 | 317 | Complete |
| `Painting` | 48 | 10,038 | 3,472 | 741 | Complete |
| `PerformanceTimeline` | 5 | 391 | 417 | 130 | Complete |
| `PermissionsPolicy` | 1 | 98 | 79 | 21 | Complete |
| `Platform` | 4 | 415 | 394 | 61 | Complete |
| `ReferrerPolicy` | 2 | 298 | 239 | 123 | Complete |
| `RequestIdleCallback` | 1 | 55 | 36 | 10 | Complete |
| `ResizeObserver` | 4 | 376 | 238 | 89 | Complete |
| `ResourceTiming` | 1 | 340 | 317 | 71 | Complete |
| `SRI` | 1 | 191 | 147 | 95 | Complete |
| `SVG` | 80 | 9,570 | 2,543 | 632 | Complete |
| `SecureContexts` | 1 | 88 | 63 | 13 | Complete |
| `Selection` | 1 | 744 | 569 | 96 | Complete |
| `Serial` | 2 | 381 | 231 | 33 | Complete |
| `ServiceWorker` | 9 | 1,365 | 842 | 248 | Complete |
| `Speech` | 11 | 504 | 596 | 111 | Complete |
| `StorageAPI` | 7 | 381 | 342 | 146 | Complete |
| `Streams` | 25 | 8,784 | 2,640 | 822 | Complete |
| `TrustedTypes` | 7 | 1,108 | 722 | 168 | Complete |
| `UIEvents` | 12 | 1,557 | 1,270 | 252 | Complete |
| `URLPattern` | 1 | 148 | 300 | 41 | Complete |
| `UserTiming` | 2 | 164 | 89 | 29 | Complete |
| `ViewTransition` | 1 | 1,046 | 567 | 319 | Complete |
| `WebAssembly` | 6 | 2,157 | 740 | 245 | Complete |
| `WebAudio` | 26 | 3,649 | 1,660 | 298 | Complete |
| `WebDriver` | 17 | 5,013 | 2,091 | 423 | Complete |
| `WebGL` | 39 | 7,163 | 1,982 | 194 | Complete |
| `WebIDL` | 10 | 2,110 | 1,139 | 279 | Complete |
| `WebSockets` | 1 | 429 | 285 | 100 | Complete |
| `WebVTT` | 2 | 326 | 445 | 221 | Complete |
| `WebXR` | 3 | 409 | 200 | 41 | Complete |
| `Worker` | 1 | 47 | 81 | 33 | Complete |
| `XHR` | 7 | 1,706 | 964 | 274 | Complete |
| `XLink` | 1 | 16 | 13 | 10 | Complete |
| `XML` | 2 | 534 | 244 | 83 | Complete |
| `XPath` | 5 | 438 | 407 | 83 | Complete |
| **Total** | **1,147** | **316,400** | **222,164** | **33,297** | **75 complete, 0 present, 0 untranslated** |

## Verification

```text
$ /Users/alex/code/v/v test .
Summary for all V _test.v files: 324 passed, 324 total.

$ cd /Users/alex/code/3rd/ladybird
$ PATH="/opt/homebrew/opt/rustup/bin:$PATH" ./Meta/ladybird.py build --jobs 8 Ladybird
[3722/3722] Linking CXX executable bin/Ladybird.app/Contents/MacOS/Ladybird
```
