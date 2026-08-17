# SVG module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/SVG`

Translation workspace: `~/code/libweb_v/svg`
Audited: 2026-08-16

All 80 upstream SVG `.cpp` implementation units have audited V mappings. All 82
headers and 76 IDL files were also cross-audited; their implemented surface is
represented by typed values, complete mutable-list operations, reflected
attributes, element/resource records, parsing results, and enums. The two
header/IDL-only mixins, `SVGURIReference` and `SVGUnitTypes`, map to `Element.href()` /
`AnimatedString` and `Units`, respectively.

| Upstream implementation units | V implementation |
| --- | --- |
| `AttributeNames.cpp`, `TagNames.cpp` | `names.v` |
| `AttributeParser.cpp` | `attribute_parser.v` |
| `Path.cpp` | `path.v` |
| `SVGAnimatedEnumeration.cpp`, `SVGAnimatedInteger.cpp`, `SVGAnimatedLength.cpp`, `SVGAnimatedLengthList.cpp`, `SVGAnimatedNumber.cpp`, `SVGAnimatedNumberList.cpp`, `SVGAnimatedRect.cpp`, `SVGAnimatedString.cpp`, `SVGAnimatedTransformList.cpp` | `types.v` |
| `SVGLength.cpp`, `SVGLengthList.cpp`, `SVGList.cpp`, `SVGNumber.cpp`, `SVGNumberList.cpp`, `SVGTransform.cpp`, `SVGTransformList.cpp` | `types.v` |
| `SVGFitToViewBox.cpp` | `elements.v`, `types.v` |
| `SVGAElement.cpp`, `SVGAnimationElement.cpp`, `SVGElement.cpp`, `SVGGraphicsElement.cpp`, `SVGGeometryElement.cpp` | `elements.v` |
| `SVGCircleElement.cpp`, `SVGEllipseElement.cpp`, `SVGLineElement.cpp`, `SVGPathElement.cpp`, `SVGPolygonElement.cpp`, `SVGPolylineElement.cpp`, `SVGRectElement.cpp` | `elements.v`, `path.v` |
| `SVGClipPathElement.cpp`, `SVGDefsElement.cpp`, `SVGDescElement.cpp`, `SVGForeignObjectElement.cpp`, `SVGGElement.cpp`, `SVGMaskElement.cpp`, `SVGMetadataElement.cpp` | `elements.v` |
| `SVGSVGElement.cpp`, `SVGStyleElement.cpp`, `SVGSymbolElement.cpp`, `SVGViewElement.cpp` | `elements.v` |
| `SVGTSpanElement.cpp`, `SVGTextContentElement.cpp`, `SVGTextElement.cpp`, `SVGTextPathElement.cpp`, `SVGTextPositioningElement.cpp`, `SVGTitleElement.cpp` | `elements.v` |
| `SVGGradientElement.cpp`, `SVGLinearGradientElement.cpp`, `SVGRadialGradientElement.cpp`, `SVGPatternElement.cpp`, `SVGStopElement.cpp` | `paint_servers.v` |
| `SVGComponentTransferFunctionElement.cpp`, `SVGFEComponentTransferElement.cpp`, `SVGFEFuncAElement.cpp`, `SVGFEFuncBElement.cpp`, `SVGFEFuncGElement.cpp`, `SVGFEFuncRElement.cpp` | `filters.v` |
| `SVGFEBlendElement.cpp`, `SVGFEColorMatrixElement.cpp`, `SVGFECompositeElement.cpp`, `SVGFEDisplacementMapElement.cpp`, `SVGFEDropShadowElement.cpp`, `SVGFEFloodElement.cpp`, `SVGFEGaussianBlurElement.cpp` | `filters.v` |
| `SVGFEMergeElement.cpp`, `SVGFEMergeNodeElement.cpp`, `SVGFEMorphologyElement.cpp`, `SVGFEOffsetElement.cpp`, `SVGFETurbulenceElement.cpp`, `SVGFilterElement.cpp`, `SVGFilterPrimitiveStandardAttributes.cpp` | `filters.v` |
| `SVGDecodedImageData.cpp`, `SVGFEImageElement.cpp`, `SVGImageElement.cpp`, `SVGScriptElement.cpp`, `SVGUseElement.cpp` | `resources.v`, `elements.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `SVG/` | 80 | 9,570 | 2,543 | 632 | Complete |

The associated declarations comprise 82 headers / 4,165 LOC and 76 IDL files /
1,022 LOC. Mapping completeness is 80/80 implementation units, 82/82 headers,
and 76/76 IDL definitions audited.

The translation covers the SVG number grammar (including signs, decimals, and
exponents), coordinate/length/integer/percentage parsing, points, table values,
view boxes, aspect-ratio, units, spread methods, and all transform functions.
It parses and serializes every path command, preserves absolute/relative state,
implements implicit line-to commands after move-to, consumes arc flags with the
required single-character grammar (including compact adjacent flags), and
resolves command endpoints. Coordinate-pair sequences preserve complete points
before an incomplete suffix, matching upstream error recovery.

The typed API includes read-only SVG number/length/list mutation rules and every
implemented common SVG list operation, animated base values (including exact
number-optional-number and percentage reflection plus legacy `xlink:href`
fallback), matrices, view boxes, viewports, and text positioning.
Element behavior covers geometry construction for all shape elements, rounded
rectangle radius defaulting/clamping, transform ordering, upstream accessibility
role decisions, trimmed UTF-16 text measurement, anchor/use semantics, mask
bounds, and cloned use trees with recursive circular-reference rejection.

Paint/filter behavior includes linked gradient inheritance with cycle guards,
non-negative radial-radius validation, normalized stops, pattern content lookup,
component-transfer lookup tables, filter enum/default parsing, reflected number
pairs, primitive defaults, and filter-region resolution. Image, decoded SVG,
script, and use resources have explicit loading, ready, failed, intrinsic-size,
and one-shot processing state.

## Boundary

DOM node allocation, generated JavaScript bindings, CSS cascade/layout node
creation, networking, bitmap decoding, display-list recording, and raster paint
surfaces remain owned by the translated DOM, bindings, CSS, loader, layout, and
painting packages. This package models the SVG-specific observable algorithms
and passes typed results to those layers. Upstream FIXMEs (notably unfinished
animation and `SVGTransform` reflection) are not presented as completed browser
integration.

`Default.css` is audited as declarative user-agent stylesheet input and is not
counted as a C++ implementation unit or copied into V code.

## Verification

```text
$ /Users/alex/code/v/v test svg
Summary for all V _test.v files: 5 passed, 5 total.

$ /Users/alex/code/v/v fmt -verify svg
(no output; exit status 0)
```
