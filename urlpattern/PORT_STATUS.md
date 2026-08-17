# URLPattern module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/URLPattern`

The `.cpp`, header, and WebIDL file were audited. The package implements both
constructor shapes, base URL resolution, string/init inputs, component
reflection, matching/testing/execution, wildcard and named-segment captures,
case-insensitive matching, nullable execution results, result dictionaries, and
regexp-group detection.

| Upstream source | V implementation |
| --- | --- |
| `URLPattern.cpp` | `url_pattern.v` |

| Upstream area | `.cpp` files | Upstream `.cpp` LOC | V implementation LOC | V test LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `URLPattern/` | 1 | 148 | 300 | 41 | Complete |

The associated declarations comprise 1 header / 62 LOC and 1 IDL file / 61
LOC. Mapping completeness is 1/1 implementation unit, 1/1 header, and 1/1 IDL
definition audited.

WHATWG URL tokenization uses `net.urllib` as the explicit parser boundary.
Parenthesized regexp source is retained and reported; native regexp execution
is intentionally delegated to the embedding layer.

Verification: `v test urlpattern` passes 1/1; formatting and diff checks pass.
