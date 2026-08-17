# Geometry module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Geometry`

Audited: 2026-08-17

Every current upstream implementation, header, and WebIDL unit was audited.
The inventory is 8 `.cpp` files / 2,157 LOC, 8 `.h` files / 568 LOC, and
8 `.idl` files / 268 LOC. The translated package has 9 implementation `.v`
files / 1,962 LOC and 10 test `.v` files / 952 LOC (84 test functions). Documentation is excluded
from the V LOC totals.

## Implementation-unit mapping

| Upstream `.cpp` | LOC | V implementation |
| --- | ---: | --- |
| `DOMMatrix.cpp` | 617 | `dom_matrix.v`, `dom_matrix_transform.v`, `dom_matrix_invert.v`, `dom_matrix_string.v`, `serialization.v` |
| `DOMMatrixReadOnly.cpp` | 999 | `dom_matrix.v`, `dom_matrix_transform.v`, `dom_matrix_invert.v`, `dom_matrix_string.v`, `serialization.v` |
| `DOMPoint.cpp` | 51 | `dom_point.v`, `serialization.v` |
| `DOMPointReadOnly.cpp` | 104 | `dom_point.v`, `serialization.v` |
| `DOMQuad.cpp` | 167 | `dom_quad.v`, `serialization.v` |
| `DOMRect.cpp` | 56 | `dom_rect.v`, `serialization.v` |
| `DOMRectList.cpp` | 72 | `dom_rect_list.v` |
| `DOMRectReadOnly.cpp` | 91 | `dom_rect.v`, `serialization.v` |
| **Total** | **2,157** | **8/8 mapped** |

The adjacent declarations are mapped with the same rows: 8/8 headers and 8/8
WebIDL definitions. This covers every dictionary, constructor, mutable and
readonly attribute, static factory, matrix operation, indexed list operation,
stringifier, default `toJSON`, and serializable interface.

## Observable coverage

The V package implements point, rectangle, quad, matrix, and live-object list
semantics; 2D/3D dictionary validation and aliases; mutable and immutable matrix
composition; scale, rotation, skew, translation, inversion, point transforms,
identity/dimension tracking, CSS transform-list parsing, Window-only string
construction, matrix stringification, typed-array conversion, bounds, and
structured serialization/deserialization. Default JSON records include all
WebIDL attributes, including derived rectangle edges and matrix `is2D` and
`isIdentity` flags.

The cross-audit also corrected rectangle-edge equality behavior: as in
upstream AK `min`/`max`, ties retain the first operand, including the sign of
negative zero. A dedicated regression covers all four derived edges.

## Boundaries

LibJS realms, garbage collection, WebIDL prototype installation, typed-array
objects, exception classes, and HTML transfer byte streams remain runtime
services. The package exposes owned V slices, typed serialization records, and
`!` errors at those boundaries. CSS transform parsing and matrix conversion use
the translated `css` package; no parser or geometry algorithm is delegated to a
host stub.

## Verification

```text
$ /Users/alex/code/v/v test geometry
Summary for all V _test.v files: 10 passed, 10 total.

$ /Users/alex/code/v/v fmt -verify geometry
(no output; exit status 0)

$ git diff --check -- geometry
(no output; exit status 0)
```
