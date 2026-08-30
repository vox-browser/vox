# CSS module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/CSS`

Translation workspace: `~/code/libweb_v/css`
Audited: 2026-08-29

Every current upstream implementation unit and its adjacent declarations were
audited against the V package. The inventory is 212 `.cpp` files / 66,305 LOC,
233 `.h` files / 18,353 LOC, and 72 `.idl` files / 994 LOC. The translated
package has 58 implementation `.v` files / 90,675 LOC and 19 test `.v` files /
3,594 LOC. Documentation is excluded from both V LOC totals.

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
| `PreferredColorScheme.cpp`, `PreferredContrast.cpp`, `PreferredMotion.cpp` | `media_queries.v`, `media_queries_minimal.v` |
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
| `StyleValues/AbstractImageStyleValue.cpp`, `StyleValues/ColorFunctionStyleValue.cpp`, `StyleValues/ColorInterpolationMethodStyleValue.cpp`, `StyleValues/ColorMixStyleValue.cpp`, `StyleValues/ColorSchemeStyleValue.cpp`, `StyleValues/ColorStyleValue.cpp`, `StyleValues/ConicGradientStyleValue.cpp`, `StyleValues/HSLColorStyleValue.cpp`, `StyleValues/HWBColorStyleValue.cpp`, `StyleValues/ImageStyleValue.cpp`, `StyleValues/LCHLikeColorStyleValue.cpp`, `StyleValues/LabLikeColorStyleValue.cpp`, `StyleValues/LightDarkStyleValue.cpp`, `StyleValues/LinearGradientStyleValue.cpp`, `StyleValues/RGBColorStyleValue.cpp`, `StyleValues/RadialGradientStyleValue.cpp`, `StyleValues/RadialSizeStyleValue.cpp` | `image_color_values.v`, `more_style_values.v` |
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

The final implementation-symbol audit inventories all 4,427 current upstream
CSS implementations: 3,903 direct candidate matches, 276 constructors or
destructors, 132 binding/GC runtime hooks, 47 language operators, 41 language
template traits, 19 reviewed consolidated-name matches, and 9 namespace
template specializations. There are zero unmatched implementations. The
generated computed-value surface and the upstream parser, calculation-node,
CSSOM rule/sheet, font, style-value, and namespace entry points are preserved
by the stateful `upstream_*_entry_points.v` records and exercised by
`upstream_entry_points_test.v`.

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

$ /Users/alex/code/v/v_old -enable-globals test css
Summary for all V _test.v files: 19 passed, 19 total.
```
