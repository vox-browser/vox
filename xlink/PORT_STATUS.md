# XLink module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/XLink`

The sole `.cpp` file and header were audited. The exact ten-name, case-sensitive
XLink attribute vocabulary and upstream macro enumeration order are retained.

| Upstream source | V implementation |
| --- | --- |
| `AttributeNames.cpp` | `attribute_names.v` |

| Upstream area | `.cpp` files | Upstream `.cpp` LOC | V implementation LOC | V test LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `XLink/` | 1 | 16 | 13 | 10 | Complete |

The associated declaration comprises 1 header / 29 LOC; this module has no IDL
file. Mapping completeness is 1/1 implementation unit and 1/1 header audited.

Verification: `v test xlink` passes 1/1; formatting and diff checks pass.
