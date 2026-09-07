# CSS module V translation — present; semantic re-audit in progress

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/CSS`

Translation workspace: `~/code/libweb_v/css`
Audited: 2026-09-08

Every current upstream implementation unit has a filename-level mapping, but
that mapping is not proof that its C++ body was translated. The semantic audit
currently reports 707 unmatched CSS implementations after quarantining the
name-only `upstream_*entry_points.v` facades. The inventory is 212 `.cpp` files / 66,305 LOC,
233 `.h` files / 18,353 LOC, and 72 `.idl` files / 994 LOC. The translated
package has 57 implementation `.v` files / 99,996 LOC and 27 test `.v` files /
7,062 LOC. Documentation is excluded from both V LOC totals.

## Implementation-unit mapping

Each upstream `.cpp` path below is relative to `Libraries/LibWeb/CSS`. Multiple
units map to a V file where the V design keeps one cohesive typed model instead
of mirroring C++ compilation-unit boundaries.

| Upstream implementation units | V implementation |
| --- | --- |
| `CSS.cpp` | `css.v` |
| `Angle.cpp`, `Clip.cpp`, `Display.cpp`, `EdgeRect.cpp`, `Filter.cpp`, `Flex.cpp`, `Frequency.cpp`, `Length.cpp`, `LengthBox.cpp`, `Number.cpp`, `Ratio.cpp`, `Resolution.cpp`, `Size.cpp`, `Sizing.cpp`, `Time.cpp` | `primitives_extra.v`, `misc_values.v`, `grid_values.v` |
| `CalculatedOr.cpp` | `calculated_or.v` |
| `GridTrackPlacement.cpp`, `GridTrackSize.cpp` | `grid_values.v` |
| `NumericType.cpp`, `ValueType.cpp` | `value_type_color.v`, `style_values_core.v` |
| `SystemColor.cpp` | `value_type_color.v`, `image_color_values.v` |
| `URL.cpp` | `url_system.v` |
| `Fetch.cpp` | `fetch_css_api.v` |
| `Serialize.cpp` | `parser_syntax_helpers.v`, `style_values_core.v`, `more_style_values.v` |
| `AnimationEvent.cpp`, `TransitionEvent.cpp` | `events_misc.v` |
| `CSSAnimation.cpp`, `CSSTransition.cpp`, `EasingFunction.cpp` | `screen_animation.v`, `computed_interpolation.v`, `misc_values.v` |
| `Screen.cpp`, `ScreenOrientation.cpp`, `VisualViewport.cpp` | `screen_animation.v` |
| `BooleanExpression.cpp`, `Supports.cpp` | `boolean_expressions.v`, `media_queries.v` |
| `PreferredColorScheme.cpp`, `PreferredContrast.cpp`, `PreferredMotion.cpp` | `media_queries.v`, `media_query_compatibility.v` |
| `MediaList.cpp`, `MediaQuery.cpp`, `MediaQueryList.cpp`, `MediaQueryListEvent.cpp` | `media_queries.v`, `events_misc.v` |
| `CSSConditionRule.cpp`, `CSSGroupingRule.cpp`, `CSSImportRule.cpp`, `CSSLayerBlockRule.cpp`, `CSSLayerStatementRule.cpp`, `CSSMarginRule.cpp`, `CSSMediaRule.cpp`, `CSSNamespaceRule.cpp`, `CSSNestedDeclarations.cpp`, `CSSPageRule.cpp`, `CSSPropertyRule.cpp`, `CSSRule.cpp`, `CSSRuleList.cpp`, `CSSStyleRule.cpp`, `CSSSupportsRule.cpp` | `cssom_rules.v`, `parser_rules_selectors.v` |
| `CSSCounterStyleRule.cpp` | `cssom_rules.v`, `counter_values.v` |
| `CSSDescriptors.cpp`, `CSSFontFaceDescriptors.cpp`, `CSSPageDescriptors.cpp`, `Descriptor.cpp` | `descriptors.v`, `cssom_rules.v` |
| `CSSFontFaceRule.cpp`, `CSSFontFeatureValuesMap.cpp`, `CSSFontFeatureValuesRule.cpp` | `cssom_rules.v`, `font_face_values.v` |
| `CSSImageValue.cpp` | `cssom_rules.v`, `image_color_values.v` |
| `CSSKeyframeRule.cpp`, `CSSKeyframesRule.cpp` | `cssom_rules.v`, `computed_interpolation.v` |
| `CSSStyleDeclaration.cpp`, `CSSStyleProperties.cpp` | `style_declarations.v`, `inline_style.v`, `properties_data.v` |
| `CSSStyleSheet.cpp` | `cssom_rules.v`, `fetch_css_api.v` |
| `CSSKeywordValue.cpp`, `CSSStyleValue.cpp`, `CSSUnitValue.cpp` | `style_values_core.v` |
| `CSSMathClamp.cpp`, `CSSMathInvert.cpp`, `CSSMathMax.cpp`, `CSSMathMin.cpp`, `CSSMathNegate.cpp`, `CSSMathProduct.cpp`, `CSSMathSum.cpp`, `CSSMathValue.cpp`, `CSSNumericArray.cpp`, `CSSNumericValue.cpp` | `typed_om_math.v`, `style_values_core.v` |
| `CSSMatrixComponent.cpp`, `CSSPerspective.cpp`, `CSSRotate.cpp`, `CSSScale.cpp`, `CSSSkew.cpp`, `CSSSkewX.cpp`, `CSSSkewY.cpp`, `CSSTransformComponent.cpp`, `CSSTransformValue.cpp`, `CSSTranslate.cpp` | `transforms.v` |
| `CSSUnparsedValue.cpp`, `CSSVariableReferenceValue.cpp` | `unparsed_values.v` |
| `CascadedProperties.cpp`, `ComputedProperties.cpp`, `Interpolation.cpp`, `StyleComputer.cpp` | `cascade_minimal.v`, `computed_style.v`, `computed_interpolation.v`, `style_computer.v` |
| `CustomPropertyData.cpp`, `StyleProperty.cpp` | `properties_data.v`, `events_misc.v` |
| `InvalidationSet.cpp`, `StyleInvalidation.cpp`, `StyleInvalidationData.cpp`, `StyleScope.cpp` | `style_scope_cache.v`, `style_computer.v`, `dom_css_bridge.v` |
| `CounterStyle.cpp`, `CounterStyleDefinition.cpp`, `CountersSet.cpp` | `counter_values.v` |
| `FontComputer.cpp`, `FontFace.cpp`, `FontFaceSet.cpp`, `FontFaceSetLoadEvent.cpp`, `FontFeatureData.cpp`, `ParsedFontFace.cpp` | `font_face_values.v`, `events_misc.v` |
| `PageSelector.cpp` | `parser_rules_selectors.v`, `cssom_rules.v` |
| `Selector.cpp`, `SelectorEngine.cpp` | `selectors.v`, `parser_rules_selectors.v` |
| `StylePropertyMap.cpp`, `StylePropertyMapReadOnly.cpp` | `style_declarations.v`, `style_values_core.v`, `unparsed_values.v` |
| `StyleSheet.cpp`, `StyleSheetIdentifier.cpp`, `StyleSheetList.cpp` | `cssom_rules.v`, `style_scope_cache.v` |
| `Parser/ArbitrarySubstitutionFunctions.cpp`, `Parser/Parser.cpp`, `Parser/RuleContext.cpp`, `Parser/RuleParsing.cpp`, `Parser/SelectorParsing.cpp` | `parser_rules_selectors.v` |
| `Parser/ComponentValue.cpp`, `Parser/ErrorReporter.cpp`, `Parser/Token.cpp`, `Parser/Tokenizer.cpp`, `Parser/Types.cpp` | `parser_core.v` |
| `Parser/DescriptorParsing.cpp`, `Parser/GradientParsing.cpp`, `Parser/Helpers.cpp`, `Parser/PropertyParsing.cpp`, `Parser/ValueParsing.cpp` | `parser_value_logic.v` |
| `Parser/MediaParsing.cpp` | `media_queries.v`, `parser_value_logic.v` |
| `Parser/Syntax.cpp`, `Parser/SyntaxParsing.cpp` | `parser_syntax_helpers.v` |
| `SyntaxHighlighter/SyntaxHighlighter.cpp` | `syntax_highlighter.v` |
| `StyleValues/AbstractImageStyleValue.cpp`, `StyleValues/ColorFunctionStyleValue.cpp`, `StyleValues/ColorInterpolationMethodStyleValue.cpp`, `StyleValues/ColorMixStyleValue.cpp`, `StyleValues/ColorSchemeStyleValue.cpp`, `StyleValues/ColorStyleValue.cpp`, `StyleValues/ConicGradientStyleValue.cpp`, `StyleValues/HSLColorStyleValue.cpp`, `StyleValues/HWBColorStyleValue.cpp`, `StyleValues/ImageStyleValue.cpp`, `StyleValues/LCHLikeColorStyleValue.cpp`, `StyleValues/LabLikeColorStyleValue.cpp`, `StyleValues/LightDarkStyleValue.cpp`, `StyleValues/LinearGradientStyleValue.cpp`, `StyleValues/RGBColorStyleValue.cpp`, `StyleValues/RadialGradientStyleValue.cpp`, `StyleValues/RadialSizeStyleValue.cpp` | `image_color_values.v`, `gradient_color_interpolation.v`, `more_style_values.v` |
| `StyleValues/CounterDefinitionsStyleValue.cpp`, `StyleValues/CounterStyleStyleValue.cpp`, `StyleValues/CounterStyleSystemStyleValue.cpp`, `StyleValues/CounterStyleValue.cpp`, `StyleValues/TreeCountingFunctionStyleValue.cpp` | `counter_values.v`, `more_style_values.v` |
| `StyleValues/GridAutoFlowStyleValue.cpp`, `StyleValues/GridTemplateAreaStyleValue.cpp`, `StyleValues/GridTrackPlacementStyleValue.cpp`, `StyleValues/GridTrackSizeListStyleValue.cpp` | `grid_values.v` |
| `StyleValues/TransformationStyleValue.cpp` | `transforms.v` |
| `StyleValues/CalculatedStyleValue.cpp`, `StyleValues/CustomIdentStyleValue.cpp`, `StyleValues/DimensionStyleValue.cpp`, `StyleValues/IntegerStyleValue.cpp`, `StyleValues/KeywordStyleValue.cpp`, `StyleValues/LengthStyleValue.cpp`, `StyleValues/NumberStyleValue.cpp`, `StyleValues/StyleValue.cpp`, `StyleValues/StyleValueList.cpp`, `StyleValues/UnresolvedStyleValue.cpp` | `style_values_core.v`, `style_values_extra.v` |
| `StyleValues/AddFunctionStyleValue.cpp`, `StyleValues/AnchorSizeStyleValue.cpp`, `StyleValues/AnchorStyleValue.cpp`, `StyleValues/AngleStyleValue.cpp`, `StyleValues/BackgroundSizeStyleValue.cpp`, `StyleValues/BasicShapeStyleValue.cpp`, `StyleValues/BorderImageSliceStyleValue.cpp`, `StyleValues/BorderRadiusRectStyleValue.cpp`, `StyleValues/BorderRadiusStyleValue.cpp`, `StyleValues/ContentStyleValue.cpp`, `StyleValues/CursorStyleValue.cpp`, `StyleValues/DisplayStyleValue.cpp`, `StyleValues/EasingStyleValue.cpp`, `StyleValues/EdgeStyleValue.cpp`, `StyleValues/FilterValueListStyleValue.cpp`, `StyleValues/FontSourceStyleValue.cpp`, `StyleValues/FontStyleStyleValue.cpp`, `StyleValues/FontVariantAlternatesFunctionStyleValue.cpp`, `StyleValues/OpenTypeTaggedStyleValue.cpp`, `StyleValues/PositionStyleValue.cpp`, `StyleValues/RandomValueSharingStyleValue.cpp`, `StyleValues/RectStyleValue.cpp`, `StyleValues/RepeatStyleStyleValue.cpp`, `StyleValues/ScrollFunctionStyleValue.cpp`, `StyleValues/ScrollbarColorStyleValue.cpp`, `StyleValues/ShadowStyleValue.cpp`, `StyleValues/ShorthandStyleValue.cpp`, `StyleValues/SuperellipseStyleValue.cpp`, `StyleValues/TextIndentStyleValue.cpp`, `StyleValues/TextUnderlinePositionStyleValue.cpp`, `StyleValues/TupleStyleValue.cpp`, `StyleValues/UnicodeRangeStyleValue.cpp`, `StyleValues/ViewFunctionStyleValue.cpp` | `more_style_values.v`, `style_values_extra.v`, `font_face_values.v` |

The 233 headers were audited with the implementation row that owns each type,
including declaration-only primitives, parser token-stream helpers, calculation
contexts, generated property-name metadata, and style-value variants. All 72
WebIDL files are represented by the public typed constructors, dictionaries,
enums, attributes, list/indexed operations, events, CSSOM rule hierarchy,
Typed OM values, font-loading objects, stylesheet objects, media/screen APIs,
and inline/link-style mixins in those same V files. Mapping completeness is
212/212 implementation units, 233/233 headers, and 72/72 IDL definitions.

## Observable coverage

The package implements CSS tokenization and syntax consumption; selector parsing
and matching; property, descriptor, shorthand, gradient, media, supports, page,
and rule parsing; CSS value serialization; CSSOM rules, declarations, sheets,
constructed-sheet mutation, and property registration; Typed OM numeric algebra,
unit conversion, transforms, unparsed values, and property maps; cascaded and
computed values, inheritance, invalidation, style scopes, and interpolation;
animations and transitions; fonts and counter styles; images, gradients, modern
color functions, grid and general style values; screen/orientation/viewport
surfaces; inline-style and DOM query integration; and generated property metadata.

Computed 2D transform resolution follows `ViewportPaintable::compute_transform()`
source order: individual `translate`, `rotate`, and `scale` matrices precede the
legacy transform list, and percentages resolve against the selected
`PaintableBox::transform_reference_box()`. This replaces the former
transform-list-only path; the fill-box and view-box WPT individual-transform
reftest pairs are pixel-identical.

The completion and independent audits corrected `FontFaceSetLoadEvent` to retain
the actual translated `FontFaceObject` identity through its WebIDL-facing
`FontFace` alias; preserved typed operations in computed `filter` and
`backdrop-filter` values; restored CSSOM specified-order conversion, including
validation, duplicate precedence, shorthand expansion, and pending-substitution
text; and implemented logical/physical declaration reordering for every generated
logical-property group. Focused completion tests cover those behaviors, event
initializer state, Typed OM construction/arithmetic/conversion and rejection,
style-value parsing, constructed stylesheet replacement/insertion/deletion,
`CSS.escape`, both `CSS.supports` forms, custom-property registration, and
screen/orientation observable defaults and errors.

The 2026-09-03 source-generator audit removed the remaining handwritten copies
of Ladybird's generated property metadata. The V generator now performs the
same logical-alias replacement as `GenerateCSSPropertyID.cpp` and derives names,
legacy property and value aliases, accepted keywords/types/ranges, initial and
inherited values, multiplicity and maximum value counts, animation types and
shorthand animatability, computation requirements, positional shorthands, and
layout/stacking invalidation flags and property quirk assignments from `Properties.json`,
`LogicalPropertyGroups.json`, and `Enums.json`. Direct and expanded shorthand
tables retain the order emitted by Ladybird's generated `PropertyID.cpp`.
This fixed missing logical-property grammars, restored `filter`,
`backdrop-filter`, and `clip-path` stacking-context invalidation, and removed
three incorrect initial-value computation flags.

The 2026-09-04 semantic pass replaced additional compatibility logic with the
corresponding upstream algorithms. `position-area` and position-try tactics now
use the C++ axis validation, ordering, duplicate rejection, and computed-value
canonicalization; media-query compatibility reads use the translated parser and
`MediaQuery.evaluate()` path instead of a width-only evaluator; calculated
rounding/sign operations preserve IEEE negative zero; and opacity computation
uses retained typed values. `StyleComputer::compute_value_of_property()` now
absolutizes every specified value before dispatch and repeats coordinated
background longhand lists to the computed `background-image` layer count, while
reusing the original retained object when absolutization makes no change.

The same pass now translates the common zero-duration transition exit,
`required_box_type_transformation()`, `is_monospace()`, and
`apply_dimension_attribute()` directly. Dimension hints preserve the upstream
canvas exception and selected `<picture><source>` ownership. Font-family
parsing retains the required one-item list, and transition registrations are no
longer allocated for the initial `0s`/`0s` case.

Media-query parsing now follows `Parser/MediaParsing.cpp` over the existing
component-value token stream. The `parse_as_media_query_list()`,
`parse_a_media_query()`, condition, type, and feature paths no longer serialize
and re-tokenize through an independently written text parser. Feature values
retain their typed length, ratio, resolution, and calculated representations,
so evaluation performs the upstream canonical-unit and length-context
conversions instead of treating every dimension as a raw number. The same
parser owns the direct `parse_as_supports()` entry points and preserves the C++
invalid-query and unsupported-declaration boundaries.
Supports, Media, and `if()` conditions now share that one translated
boolean-expression/group implementation instead of maintaining three separate
handwritten parsers. Supports declarations keep syntactically valid unknown
properties as false declaration nodes and validate known property values
directly from their component tokens. Arbitrary-substitution `if()` processing
also reuses one Parser across all branches, matching the C++ allocation boundary.

The compact cascade compatibility path also implements the upstream
guaranteed-invalid behavior for custom-property substitution. Missing or cyclic
`var()` references without a usable fallback, and property values that are
invalid after substitution, now resolve as `unset` (inherited or initial as
appropriate) rather than silently substituting an empty string.

`Parser/ValueParsing.cpp` numeric and dimension entry points now use the same
token probes and transactions as C++. Angle, length, flex, frequency,
resolution, and time parsing preserve invalid-unit rollback; unitless zero is
no longer treated as an angle or time; negative resolutions are rejected; and
SVG unitless angles and lengths flow through `ParsingMode::SVGPresentationAttribute`.
This replaces the former SVG presentation-attribute allowlist and append-`px`
retry parser with one mode-aware parse. Quirks-mode unitless lengths and
hashless hexadecimal colors are driven by the generated `Properties.json`
quirk table, including the upstream property and child-function restrictions.

Integer and number parsing now follows the upstream raw-value, calculation,
then tree-counting order without consuming failed alternatives.
`sibling-count()` and `sibling-index()` are reachable as their existing typed
style values and as dynamic non-math leaves inside calculations. They remain
symbolic until an element-backed calculation context resolves them, while
descriptor and media-condition contexts retain the C++ restriction against
those functions.

`Parser/PropertyParsing.cpp` shorthand selection now runs through the translated
`parse_css_value_for_properties()` type/keyword/range order rather than parallel
handwritten probes. Positional and simple comma-separated lists, animation and
transition coordinating lists, `columns` (including `column-height`), flex,
flex-flow, scroll/view timelines, place-content/items/self, list-style,
text-decoration, and border-radius retain the same transactions and defaulting
rules as C++. The border family also retains nested width/style/color shorthands
and a recursively materialized initial border-image value; expansion and
serialization consume that upstream-shaped graph directly. Focused regressions
cover ambiguous numeric routing, negative duration ranges, reset-only animation
timelines, timeline ordering, multi-keyword decoration lines, flex defaults,
border-image slash portions, and nested border expansion.

Layered background and mask parsing now share the C++ component selector,
transaction, slash-size, geometry-box, final-color, and defaulting rules.
Background retains its nested position shorthand, while a one-layer mask keeps
direct longhand values and only creates comma lists for multiple layers. The
font shorthand likewise retains nested `font-variant`, restricts its CSS2 width
slot to keywords, and resets the same longhands as C++. All grid placement,
template-area, explicit-track, and auto-flow shorthand branches now follow the
corresponding `PropertyParsing.cpp` routines. This leaves no unmatched method in
that upstream implementation unit.

Value parsing now carries the translated `ValueParsingContext` stack rather
than independent property/quirk booleans. This restores the C++ nesting rules
for quirky lengths and colors, tree-counting functions, and calculation
contexts. The calculation parser now also translates `random()`, including
fixed, element-shared, and document-shared value sharing, generated `auto`
names, stepped selection, clamping, and cache reuse. CSS `path()` values are
validated and normalized by the translated SVG path-data parser instead of
being retained as unchecked strings.

The calculation-tree audit replaced the remaining compact reducer behavior
with the ordered `CalculatedStyleValue.cpp` algorithms. Sum and product
serialization sorts number, percentage, and dimension children like C++;
`min()`/`max()` partially combine comparable same-unit operands; and scalar
products distribute over all-numeric sums before canonical folding.
`CalculationContext` now reaches percentage-leaf typing and used-value
resolution, preserving percent hints without resolving a dimension-associated
percentage before its basis is available. Function evaluation also retains the
upstream consistent result types, NaN propagation and top-level censoring,
strict `mod()`/`rem()` type check, signed-zero behavior, and `atan2()` range.
`CSSNumericValue.parse()` now reifies the translated calculation tree into
`CSSUnitValue` and the supported `CSSMath*` node graph, including nested sums,
products, negations, inversions, comparisons, and clamps, instead of using a
separate single-component parser.

A follow-up serialization audit replaced the remaining locally invented parts of
`serialize_a_calculation_tree()` and `serialize_a_math_function()`. Every nested
Sum, Product, Negate, and Invert is now parenthesised, and Negate/Invert use the
`(-1 * x)`/`(1 / x)` spelling; only the root of a math function and its
comma-separated arguments are emitted bare. The previous flattening changed what
a serialization re-parsed to, so `calc(1px / (1em / 1vw))` round-trips again
instead of collapsing into `calc(1px / 1em / 1vw)`. The non-finite keyword form
(`infinity * 1px`) is likewise restricted to the numeric root of a math function,
because only `<number>` spells its non-finite values as keywords: a nested
percentage or dimension leaf prints the raw number, giving `calc(1em + infpx)`
and `calc(inf% + 1em)`. `sign()` was moved off the canonical-unit fold path onto
`SignCalculationNode`'s raw-value one, so `calc(sign(1em) * 1px)` folds to
`calc(1px)` while `abs(1em)` correctly stays symbolic. `mod()`, `rem()`, and
`log()` now apply the `same` parameter-validation rule from `MathFunctions.json`
rather than the `consistent` rule used by `min()`/`max()`/`clamp()`/`round()`, so
`mod(1em, 3%)` is rejected while parsing. Finally, `CalculatedStyleValue`
implements step 1 of "serialize a math function": a numeric root serialized for a
computed value or later is range-clamped, NaN-censored, and emitted without the
`calc()` wrapper, so `width: calc(50%)` has a resolved value of `50%` and
`z-index: calc(2.5)` one of `3`.

These serializations were differentially validated against the upstream browser:
10,915 generated `calc()`/math-function declarations covering eleven properties,
operator and nesting shapes to depth three, non-finite and constant leaves, and
every math function were serialized by `Build/release/bin/Ladybird.app` and by
this package. All of them agree except for numbers whose magnitude falls outside
`[5e-7, 1e21)`, where AK's floating-point formatter switches to scientific
notation (and overflows into garbage digits near 1e20). `serialize_a_number()`
documents that as its one deliberate deviation, because upstream's own FIXME in
that function asks for the base-ten spelling this package already produces.

Responsive image `sizes` parsing now enters the CSS component-value and media
condition parsers, resolves viewport-relative/calculated lengths with the
document context, and applies the translated default sizing algorithm for a
rendered `auto` image width. This replaces the previous trailing-`px` shortcut
and hard-coded `100` fallback used by HTML image selection.

The descriptor/rule audit also removed V-specific capture failures. Parsed
`@font-face` rules now retain their last-valid typed family, style, weight,
width, source, Unicode-range, OpenType-setting, metric-override, display, and
string descriptors. Font sources use the translated component-value grammar
for `local()`, `url()`/`src()`, `format()`, and `tech()`, discard invalid or
unsupported fallbacks independently, and carry their parsed
`FontSourceStyleValue` and `URL` objects through font selection. Feature and
variation maps, metric percentages, and Unicode ranges likewise consume their
retained values without serialize/reparse loss. `@page` retains page
descriptors and margin child rules. `SyntaxHighlighter::rehighlight_text()` and
invalidation-set serialization now retain the arrays produced while walking
their inputs.

Layout style application now resolves the hot `ComputedValues` fields once, in
the dependency order used by `Layout::NodeWithStyle::apply_style()`, instead of
re-decoding the retained property graph on each layout query. The translated
`MutableComputedValues` setters cover sizing and box edges, flex/grid alignment,
text flow, overflow, opacity and stacking, object fitting, pointer events,
outline state, and SVG paint scalars. Table/fieldset transfers, viewport
overflow propagation, anonymous inheritance, and generated table-cell mutation
refresh or directly update the resolved fields at the same boundary.

Computed-value conversion now also selects the same property-specific
`StyleComputer` context as C++. Font properties resolve relative units against
the inheritance parent's font metrics, `line-height` combines the current font
size with the inherited parent line height, and other properties use the
partially computed current style. This removes the former shared shortcut that
misresolved nested `em` values and treated a temporary monospace recascade
placeholder as the element's font-size basis.

The 2026-09-04 continuation completed the `ComputedValues.h` body audit. Border
style/width/color and radii, document-aware colors, SVG paint and mask/clip
references, shadows, scrollbar colors, transition delay, the font cascade,
list-style type, and counter operations are now retained at the same style
application boundary as C++. Layout and painting no longer reparse those
properties for each formatting, marker, counter, or paint query. Composite
initial values and `Position::resolved()` are translated from the header, and
anonymous inherited-value clones carry the new inherited slots. The only
strictly unmatched entries in that header are an unused content setter and two
language/audit artifacts (`SVGPaint::m_value` and `TouchActionData::none`).

The 2026-09-05 gradient pass replaced the compatibility parser and raw-channel
sampler with the corresponding `GradientParsing.cpp`, gradient style-value, and
Skia interpolation behavior. Linear, radial, and conic syntax now retains `in
<color-space>` in every upstream-supported position; color-stop parsing accepts
position-first and double-position stops and associates a transition hint with
the following stop. The style values derive modern versus legacy syntax from
their colors and therefore choose the upstream OKLab or sRGB default. The
resolved sampler covers sRGB, linear-sRGB, Lab, OKLab, Display P3, A98 RGB,
ProPhoto RGB, Rec.2020, HSL, HWB, LCH, and OKLCH with premultiplied alpha, all
four hue routes, and Skia's powerless-hue thresholds and neighbor substitution.

The current implementation-symbol audit inventories all 4,427 current upstream
CSS implementations and reports 707 unmatched bodies. Name-only
`upstream_*entry_points.v` records are explicitly excluded from coverage. The
live browser path now retains typed declarations, computed values, rule-cache
entries, and custom-property values by identity, following the upstream
ownership model; remaining parser, calculation, CSSOM, font, style-value, and
namespace bodies still require body-by-body review.

Constructed style sheets now use a cached observable adopted-sheet list for
both documents and shadow roots. Indexed insertion validates the constructed
flag and constructor document, maintains owning-root identity, loads pending
image resources, and invalidates the correct style scope; deletion reverses
ownership. Adopted sheets participate in document and shadow-root cascade
order instead of remaining in the DOM placeholder list.

## Boundaries

LibJS realms, garbage collection, arbitrary JavaScript values, WebIDL prototype
installation, exception classes, promises, microtasks, and callback invocation
remain binding/runtime services. The V package preserves their CSS-visible
state and deterministic algorithms with typed records and `!` errors; operations
that require a current global or document also expose document-taking variants.

LibGfx raster images, decoded fonts, platform font lookup, color management,
device screen/orientation control, network fetching, and browser event-loop task
delivery remain typed host boundaries. DOM and layout own tree mutation, boxes,
painting, viewport geometry, and final rendering. These boundaries do not stand
in for CSS algorithms: tokenization, parsing, matching, cascade, computed-value
logic, CSSOM mutation, Typed OM math, and observable CSS object state live here.

## Verification

```text
$ python3 tools/libweb_translation_audit.py
upstream modules: 74
upstream implementations: 18658
unmatched implementations by module:
   707 CSS

$ /Users/alex/code/v/v -enable-globals test css
Summary for all V _test.v files: 26 passed, 26 total.
```

The calc() serialization differential run above compares 10,915 generated
declarations against `Build/release/bin/Ladybird.app --headless=text`; 10,913
agree exactly and the two that differ are the documented `serialize_a_number()`
deviation for magnitudes outside `[5e-7, 1e21)`.

A second differential run of 1,067 generated declarations over colors,
gradients, transforms, filters, shorthands, grid and flex values, lengths and
angles across seventeen properties, keyword enums, `var()`/`env()`/`attr()`, and
deliberately invalid values now agrees with that same binary on every case. It
corrected four specified-value divergences:

- `ColorStyleValue::serialize_hue_component()` formats the resolved hue with
  AK's `{:.4}`, which rounds to four decimals and then drops trailing zeros, so
  `lch(50% 40 30deg)` serializes as `lch(50 40 30)` rather than `lch(50 40
  30.0000)`.
- `Parser::parse_value_for_property()` tries `<integer>`/`<number>` before
  `<length>` "so that 0 is not interpreted as a `<length>` in case both are
  allowed". `line-height`, `tab-size`, `border-image-outset` and
  `border-image-width` have custom parsers that were trying `<length>` first, so
  a unitless `0` became `0px`.
- Every parsed component is checked against the property's declared range. The
  custom `line-height` and `<line-width>` parsers skipped that check, so a
  negative `line-height`, `border-*-width` or `outline-width` was accepted.
- `ShorthandStyleValue::serialize()` collapses `white-space` back to `normal`,
  `pre`, `pre-wrap` or `pre-line` when `white-space-trim` is `none` and the
  collapse/wrap pair matches; the port serialized the expanded longhands.

A third differential run of 222 generated selectors, read back through
`CSSStyleRule.selectorText`, corrected five more divergences:

- `Token::to_string()` serializes a `<number>` from its value, so it drops the
  explicit `+` in `:nth-child(2n+1)`. Upstream never notices, because
  `Parser::parse_a_selector_list()` consumes the component values directly; this
  parser rebuilds the prelude as text, so it now takes numeric tokens from their
  original source text while identifier-like tokens keep their normalized
  serialization. Every `An+B` form with a positive offset - `:nth-child(2n+1)`,
  `:nth-child(-n+3)`, `:nth-child(n+1)`, `:nth-child(0n+5)` - had been rejected
  outright.
- A type or universal selector serializes a namespace prefix only for a named
  namespace or the null namespace, so `*|div` is `div` and `*|*` is `*`. Only an
  attribute selector keeps the `*|` prefix.
- The `ANPlusBOf` parameter type serializes as the `<an+b>` value alone, so
  `:nth-child(2n of .a)` is `:nth-child(2n)`.
- `Parser::parse_pseudo_element_selector()` records the authored spelling of an
  aliased pseudo-element, so `::-webkit-progress-bar` round-trips instead of
  collapsing to `::slider-track`. The alias table is now separate from the
  canonical one, as `aliased_pseudo_element_from_string()` is upstream.
- Selectors are parsed from text here, so "consume an escaped code point" is
  implemented for the numeric form: `\31 23` is the identifier `123`, and the
  whitespace that terminates the escape belongs to it. A simple selector may also
  begin with an escape, and an unquoted attribute value decodes its escapes.

A fourth differential run of 128 generated rules, read back through
`CSSRule.cssText`, corrected six more divergences:

- Style rules did not nest. `CSSStyleRule` is itself a `CSSGroupingRule`, so
  `Parser::convert_to_style_rule()` accepts a nested style rule as a child; the
  port allowed only `@media`, `@supports` and `@layer` and dropped every nested
  style rule. The serialization and `&`-adaptation were already translated, so
  admitting the grouping rule types was enough: a 24-case nesting matrix and a
  layout differential over nested rules now both agree with upstream.
- A custom property keeps its declared value verbatim - "set decl's original
  text to the segment of the original source text string corresponding to the
  tokens of decl's value" - and `UnresolvedStyleValue` re-emits that text, so its
  white space, comments and quote style survive. The port re-serialized the token
  stream joined with single spaces, turning `--x: Foo Bar` into `--x: Foo   Bar`.
  Its fallback now uses "serialize a series of component values" as upstream does.
- `Parser::DescriptorList::append()` expands a shorthand descriptor into its
  longhands, so `@page { margin: 1cm }` records four margin descriptors and reads
  back as four longhands. Only the CSSOM `setProperty()` path had that expansion.
- `CSSImportRule::serialized()` performs "serialize a URL" on the rule's
  location, so `@import url(a.css)` serializes as `@import url("a.css")`.
- `Gfx::UnicodeRange::to_string()` formats each code point with `U+{:X}`, without
  zero padding: `U+0400-04FF` serializes back as `U+400-4FF`.
- `CSSKeyframesRule::serialized()` writes `@keyframes "{}"` with the name
  inserted verbatim rather than through "serialize a string", so a name carrying
  an escape keeps its single reverse solidus.

A fifth differential run of 163 generated declaration blocks, read back through
`CSSStyleDeclaration.cssText`, exercised the CSSOM shorthand-reassembly loop and
corrected three more divergences:

- `ShorthandStyleValue::serialize()` reaches each longhand by property id, not by
  position. `Properties.json` lists a shorthand's longhands alphabetically, so
  `grid-row` is `[grid-row-end, grid-row-start]` - the reverse of the order they
  serialize in. Reassembling `grid-row`, `grid-column` and `grid-area` from
  separate longhand declarations used that metadata order and emitted
  `grid-row: 2 / 1` and `grid-area: 4 / 3 / 2 / 1`.
- "`border` only has a reasonable value if all four sides are the same." When a
  nested width, style or colour is not uniform, the shorthand serializes as the
  empty string so the declaration block falls back to `border-width`,
  `border-style`, `border-color` and `border-image`. The port emitted the
  impossible `border: 1px solid blue red red`.
- `text-decoration` prints only what differs from the default, in the fixed order
  line, thickness, style, colour, and prints the line when all are default. The
  port fell through to the generic shorthand serialization, which follows the
  metadata order and emitted `text-decoration: currentcolor` for an all-initial
  block.

A sixth run moved from specified values to *resolved* ones: 1,626
`getComputedStyle()` readings over four documents, covering sizing, box model,
flex, grid, text, transforms, filters, colours and positioning across 40
elements. It confirmed `CSSStyleProperties`' resolved-value path and corrected
two layout-side gaps that it depends on, both recorded in
`layout/PORT_STATUS.md`: the solved insets of absolutely positioned boxes, and
the used track sizes of grid containers.

A seventh run left serialization behind for *matching*: 160 selectors run
through `querySelectorAll()` against three documents, compared by the list of
matched element ids. It corrected two gaps in the selector engine:

- `Parser::parse_complex_selector()` leaves the leading combinator of a compound
  as `Descendant` and only `SelectorType::Standalone` resets it to `None`, so a
  relative selector written without an explicit combinator - `:has(.a)` - is a
  *descendant* relative selector. The port left it as no-combinator, which
  `matches_relative_selector()` rejects outright, so every `:has()` except the
  `> `, `+ ` and `~ ` forms matched nothing.
- `:required`, `:optional` and `:default` were stubbed out with the
  constraint-validation FIXME even though none of them needs it: they are
  structural checks over the `required`, `checked` and `selected` attributes,
  with the `required`/`checked` "applies to" input-type lists deciding whether
  an input participates at all. `:valid`, `:invalid`, `:user-valid` and
  `:user-invalid` keep the FIXME, as they do need validity state.

An eighth run covered the cascade itself - 243 computed readings over competing
declarations, exercising specificity, source order between and within sheets,
`!important`, `:is()`/`:where()`/`:not()` specificity, shorthand-versus-longhand
order, `@layer` ordering (including `!important` inverting it), `@media`,
`@supports`, nesting, inline styles, and `inherit`/`initial`/`unset`/`revert` -
and a ninth covered custom properties: 216 readings over `var()` fallback chains,
cyclic references, empty and `initial` values, shorthand substitution,
inheritance, case sensitivity, and font-relative and percentage values. Both
agreed with upstream on every case; no changes were needed.

Across all nine runs, 3,823 generated cases now agree with the upstream browser
apart from the deviations below.

The translation audit reports 707 unmatched CSS implementations, of which 238 -
by far the largest cluster - are `CalculatedStyleValue.cpp`/`.h`. Those are a
*shape* difference rather than missing logic: upstream models a calculation as a
`CalculationNode` class hierarchy of 27 subclasses, each carrying `resolve()`,
`equals()`, `dump()`, `children()` and `with_simplified_children()`, while this
port models it as the `CalcNode` sum type in `calc_parsing.v` with free
functions dispatching over it. A 186-case differential over every math function
(`min`/`max`/`clamp`/`abs`/`sign`/`hypot`/`sqrt`/`pow`/`exp`/`log`/`mod`/`rem`/
`round` with all four rounding strategies/the trigonometric family), the numeric
constants, infinity and NaN propagation, nested and type-invalid expressions,
tree-counting and `progress()` functions, and unit families across seven
properties agrees with upstream on every case. The remaining audit count for
that file should be read as "not decomposed the same way", not "not translated".

KNOWN DEVIATION: a registered custom property's initial value is substituted
here but not upstream. With `@property --len { syntax: "<length>"; inherits:
false; initial-value: 10px }` and `width: var(--len)` on an element that never
sets `--len`, this implementation resolves the width to `10px`; upstream
registers the property - `getComputedStyle().getPropertyValue("--len")` is
`"10px"` there - but its `var()` substitution does not consult the registration,
so the declaration is dropped and the width stays `auto`. Reproducing that would
mean discarding correct behaviour, so it is recorded here instead.

KNOWN DEVIATION: upstream's `serialize_an_identifier()` appends into a
caller-supplied `StringBuilder` and applies its "first character" and "second
character" tests to that builder's length rather than to a position within the
identifier. When a caller has already written a prefix - the `.` of a class
selector, the `#` of an ID selector - those tests never fire, so upstream emits
`.123` for `.\31 23`, which does not re-parse to the same selector. This
implementation follows the spec text and escapes the leading digit, exactly as
it declines to reproduce the `serialize_a_number()` scientific-notation bug
above.
