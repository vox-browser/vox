# CookieStore module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/CookieStore`

Translation workspace: `~/code/libweb_v/cookiestore`
Audited: 2026-08-16

Both upstream CookieStore `.cpp` implementation units, their headers, and the
associated IDL dictionaries and enum have typed V mappings.

| Upstream implementation unit | V implementation |
| --- | --- |
| `CookieStore.cpp` | `cookie_store.v`, `cookie_backend.v` |
| `CookieChangeEvent.cpp` | `cookie_change_event.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `CookieStore/` | 2 | 900 | 997 | 392 | Complete |

The port covers the CookieStore dictionaries and same-site enum, asynchronous
typed get/getAll/set/delete promises, opaque-origin and options-URL checks,
cookie querying, name/value normalization, prefix and attribute validation,
default paths, expiry capping, the explicit PageClient-style cookie backend,
CookieChangeEvent construction, cached-list immutability, `onchange`, and queued
changed/deleted event dispatch.

Ladybird performs cookie-jar retrieval and mutation through `PageClient` in the
UI process and uses LibJS/WebIDL promises. The V translation preserves that
boundary as `CookieStoreBackend`, uses the translated HTML event loop for both
parallel-operation completion and DOM-manipulation events, and exposes typed
observable promises. Partitioned-cookie mutation remains the same explicit
FIXME as the audited upstream implementation.

## Verification

```text
$ /Users/alex/code/v/v test cookiestore
Summary for all V _test.v files: 2 passed, 2 total.
```
