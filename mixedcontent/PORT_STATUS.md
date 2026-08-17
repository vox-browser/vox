# MixedContent module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/MixedContent`

Translation workspace: `~/code/libweb_v/mixedcontent`
Audited: 2026-08-16

The sole upstream implementation unit and header map to typed V request,
response, URL, destination, initiator, environment-settings, and blocking
operations. All allow/block and passive-content upgrade branches are covered.

| Upstream implementation unit | V implementation |
| --- | --- |
| `AbstractOperations.cpp` | `abstract_operations.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `MixedContent/` | 1 | 121 | 125 | 105 | Complete |

## Verification

```text
$ /Users/alex/code/v/v test mixedcontent
Summary for all V _test.v files: 1 passed, 1 total.

$ /Users/alex/code/v/v fmt -verify mixedcontent
(no output; exit status 0)
```
