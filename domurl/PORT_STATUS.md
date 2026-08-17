# DOMURL module V translation — complete

Complete, audited translation of `Libraries/LibWeb/DOMURL`.

| Upstream `.cpp` | LOC | V mapping |
|---|---:|---|
| `DOMURL.cpp` | 492 | `dom_url.v` |
| `Origin.cpp` | 103 | `dom_url.v` |
| `URLSearchParams.cpp` | 353 | `url_search_params.v` |
| `URLSearchParamsIterator.cpp` | 68 | `url_search_params.v` |

- Upstream inventory: **4 `.cpp` / 1,016 LOC**, **4 `.h` / 241 LOC**,
  **3 `.idl` / 63 LOC**; **1,320 LOC total**.
- V implementation: **932 LOC** in 2 `.v` files.
- Focused tests: **270 LOC** in 1 `_test.v` file (**21 tests**).
- The audit added URL and Origin, live SameObject `searchParams`, component
  getters/setters, relative parsing, origin/default-port behavior, iterator and
  callback APIs, plus direct partition-checked FileAPI blob-store integration.
  The final cross-audit added invalid-UTF-8 replacement for form decoding,
  special-query percent encoding, setter host/port validation, default-port
  normalization, opaque-origin classification, and inherited blob URL origins.
  The independent cross-audit corrected percent-encoded component getters and
  serialization (including user info, paths, fragments, IPv6 hosts, and empty
  fragments/queries), host casing and validation, default-port changes, and
  the URL Standard's special/non-special scheme-transition restrictions.

URL parsing uses V's typed `net.urllib` record. Public-suffix/registrable-domain
same-site classification remains an explicit host-service boundary. LibJS owns
WebIDL overload conversion, realms/GC, and iterator protocol objects; the live
list and iterator algorithms themselves are translated here.

Verification:

```text
$ /Users/alex/code/v/v test domurl
Summary for all V _test.v files: 1 passed, 1 total.

$ /Users/alex/code/v/v fmt -verify domurl
(no output; exit status 0)
```
