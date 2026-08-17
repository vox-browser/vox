# GPC module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/GPC`

Translation workspace: `~/code/libweb_v/gpc`
Audited: 2026-08-16

The sole upstream implementation unit, its header, and its Web IDL mixin are
mapped to typed V. The getter reads the canonical Loader configuration just as
Ladybird uses `ResourceLoader::the()` to decide whether a `Sec-GPC` field would
be sent.

| Upstream implementation unit | V implementation |
| --- | --- |
| `GlobalPrivacyControl.cpp` | `global_privacy_control.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `GPC/` | 1 | 21 | 16 | 13 | Complete |

## Verification

```text
$ /Users/alex/code/v/v test gpc
Summary for all V _test.v files: 1 passed, 1 total.

$ /Users/alex/code/v/v fmt -verify gpc
(no output; exit status 0)
```
