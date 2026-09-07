#!/usr/bin/env python3
"""Inventory upstream LibWeb/HTML methods and candidate V translations.

This deliberately audits symbols, not filenames. A V function is only a
candidate match when its name is identical to the C++ method name or ends in
``_<method>`` (the convention used for DOM-backed HTML algorithms). The report
therefore errs on the side of exposing work: renamed/consolidated algorithms
must be reviewed rather than silently counted as complete.
"""

from __future__ import annotations

import argparse
import collections
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path


CPP_METHOD = re.compile(
    r"(?m)^(?![ \t/#])[^\n;{}]*?\b"
    r"(?P<class>[A-Za-z_]\w*(?:::[A-Za-z_]\w*)*)::"
    r"(?P<name>~?[A-Za-z_]\w*|operator[^ (]+)\s*\("
)
HEADER_CLASS = re.compile(
    r"\b(?:class|struct)\s+(?:WEB_API\s+)?"
    r"(?P<name>[A-Za-z_]\w*(?:::[A-Za-z_]\w*)*)[^;{]*\{"
)
HEADER_INLINE_METHOD = re.compile(
    r"(?:^|[;}]\s*)[^;{}=]*?\b"
    r"(?P<name>~?[A-Za-z_]\w*|operator[^ (]+)\s*"
    r"\([^;{}]*\)\s*"
    r"(?:const\s*)?(?:noexcept\s*)?(?:override\s*)?(?:final\s*)?"
    r"(?:requires\s+[^{}]+)?\{"
)
CPP_FREE_FUNCTION_HEAD = re.compile(
    r"(?m)^(?![ \t/#])"
    r"(?!(?:class|enum|namespace|static_assert|struct|typedef|using)\b)"
    r"[^\n;{}]*?\b(?P<name>operator\s*[^\s(]+|[A-Za-z_]\w*)\s*\("
)
HEADER_QUALIFIED_TEMPLATE_METHOD = re.compile(
    r"(?m)^(?![ \t/#])[^\n;{}]*?\b"
    r"(?P<class>[A-Za-z_]\w*(?:::[A-Za-z_]\w*)*)::"
    r"(?P<name>~?[A-Za-z_]\w*|operator[^ (<]+)\s*"
    r"<[^;\n{}]+>\s*\([^;\n{}]*\)[^;\n{}]*\{"
)
V_FUNCTION = re.compile(
    r"(?m)^(?:pub\s+)?fn\s+"
    r"(?:(?:\((?P<receiver>[^\n)]*)\)\s+)|(?:(?P<associated>[A-Za-z_]\w*)\.))?"
    r"(?P<name>[A-Za-z_]\w*)\s*(?:\[[^\]\n]+\]\s*)?\("
)
V_INTERFACE = re.compile(
    r"(?ms)^\s*(?:pub\s+)?interface\s+(?P<name>[A-Za-z_]\w*)\s*\{(?P<body>.*?)^\s*\}"
)
V_INTERFACE_METHOD = re.compile(r"(?m)^\s*(?P<name>[A-Za-z_]\w*)\s*\(")
V_STRUCT = re.compile(
    r"(?m)^(?:pub\s+)?struct\s+(?P<name>[A-Za-z_]\w*)(?:\[[^\]\n]+\])?\s*\{"
)
V_STRUCT_FIELD = re.compile(r"^\s*(?P<name>[A-Za-z_]\w*)\s+\S")
RUNTIME_ONLY_METHODS = {"initialize", "visit_edges", "finalize"}
# These WebIDL dictionaries enter the standalone port as typed V values. Their
# C++ from_value() methods only inspect JS objects and manufacture callback
# wrappers, work which belongs to the embedding/bindings layer rather than the
# typed Streams implementation.
BINDING_RUNTIME_METHODS = {
    ("Transformer", "from_value"),
    ("UnderlyingSink", "from_value"),
    ("UnderlyingSource", "from_value"),
}
NAMESPACE_TEMPLATE_CLASSES = {"IPC"}
# C++ customization points whose behavior is supplied by V's built-in map,
# equality, hashing, and formatting machinery rather than translated methods.
LANGUAGE_TEMPLATE_TRAIT_CLASSES = {"Formatter", "SentinelOptionalTraits", "Traits"}
V_KEYWORD_METHODS = {"type": "type_", "is": "is_", "match": "match_"}

# WebGL's C++ inheritance hierarchy splits the public context, implementation,
# overload, and shared-base methods across six owners. The standalone V port
# deliberately keeps one context record so validation and GL state cannot
# diverge between those layers.
CONSOLIDATED_OWNER_ALIASES: dict[str, tuple[str, ...]] = {
    "WebGLRenderingContextImpl": ("WebGLRenderingContext",),
    "WebGL2RenderingContextImpl": ("WebGLRenderingContext",),
    "WebGLRenderingContextOverloads": ("WebGLRenderingContext",),
    "WebGL2RenderingContextOverloads": ("WebGLRenderingContext",),
    "WebGLRenderingContextBase": ("WebGLRenderingContext",),
    "WebGL2RenderingContext": ("WebGLRenderingContext",),
    "ANGLEInstancedArrays": ("WebGLExtension",),
    "EXTBlendMinMax": ("WebGLExtension",),
    "EXTColorBufferFloat": ("WebGLExtension",),
    "EXTRenderSnorm": ("WebGLExtension",),
    "EXTTextureFilterAnisotropic": ("WebGLExtension",),
    "EXTTextureNorm16": ("WebGLExtension",),
    "OESElementIndexUint": ("WebGLExtension",),
    "OESStandardDerivatives": ("WebGLExtension",),
    "OESVertexArrayObject": ("WebGLExtension", "WebGLRenderingContext"),
    "WebGLCompressedTextureS3tc": ("WebGLExtension",),
    "WebGLCompressedTextureS3tcSrgb": ("WebGLExtension",),
    "WebGLDrawBuffers": ("WebGLExtension",),
    # Painting keeps the native class hierarchy as one renderer-independent
    # state record. Specialized SVG/control/viewport classes differ in the C++
    # tree because they own GC and backend resources; their observable painting
    # state and algorithms are represented by PaintableState in V.
    "Paintable": ("PaintableState",),
    "PaintableBox": ("PaintableState",),
    "PaintableWithLines": ("PaintableState",),
    "ViewportPaintable": ("PaintableState",),
    "CanvasPaintable": ("PaintableState",),
    "CheckBoxPaintable": ("PaintableState",),
    "FieldSetPaintable": ("PaintableState",),
    "ImagePaintable": ("PaintableState",),
    "MarkerPaintable": ("PaintableState",),
    "NavigableContainerViewportPaintable": ("PaintableState",),
    "RadioButtonPaintable": ("PaintableState",),
    "TextPaintable": ("PaintableState",),
    "VideoPaintable": ("PaintableState",),
    "SVGClipPaintable": ("PaintableState",),
    "SVGForeignObjectPaintable": ("PaintableState",),
    "SVGGraphicsPaintable": ("PaintableState",),
    "SVGMaskPaintable": ("PaintableState",),
    "SVGPatternPaintable": ("PaintableState",),
    "SVGPathPaintable": ("PaintableState",),
    "SVGSVGPaintable": ("PaintableState",),
    "DisplayListPlayerSkia": ("DisplayListPlayer",),
    "BordersDataDevicePixels": ("DeviceBordersData",),
    "ClipData": ("ClipVisualData",),
    "EffectsData": ("EffectsVisualData",),
    "ChromeWidget": ("Scrollbar",),
    "SelectionStyle": ("PaintableState",),
    "DrawScaledImmutableBitmap": ("DrawScaledBitmap",),
    "DrawRepeatedImmutableBitmap": ("DrawRepeatedBitmap",),
    "FillRectWithRoundedCorners": ("FillRoundedRect",),
    "PaintScrollBar": ("PaintScrollbar",),
    # CSS collapses inheritance-only wrappers into the concrete translated
    # records. Never point coverage at a synthetic facade: the named owner must
    # execute the engine's real typed implementation.
    "ComputedValues": ("ComputedProperties",),
    "InitialValues": ("ComputedProperties",),
    "MutableComputedValues": ("ComputedProperties",),
    "Parser": ("Parser", "RuleSelectorParser"),
    "TokenStream": ("ComponentValueStream", "ParserTokenStream"),
    "FontFace": ("FontFaceObject",),
    "CSSStyleDeclaration": ("CSSStyleProperties",),
    "StyleSheet": ("CSSStyleSheet",),
    # BooleanExpression's C++ subclass family is one tagged, typed tree in V.
    # Evaluation, serialization, and debug dumping dispatch on `kind`; this is
    # a representation consolidation, not a symbol-only facade.
    "GeneralEnclosed": ("BooleanExpression",),
    "BooleanNotExpression": ("BooleanExpression",),
    "BooleanExpressionInParens": ("BooleanExpression",),
    "BooleanAndExpression": ("BooleanExpression",),
    "BooleanOrExpression": ("BooleanExpression",),
    "ConstantBooleanExpression": ("BooleanExpression",),
    # SVG's Web-facing wrapper classes share compact value records and one
    # Element representation in the standalone port.
    "AttributeParser": ("Scanner",),
    "SVGLength": ("SvgLength",),
    "SVGNumber": ("SvgNumber",),
    "SVGLengthList": ("LengthList",),
    "SVGNumberList": ("NumberList",),
    "SVGTransform": ("Transform",),
    "SVGTransformList": ("TransformList",),
    "SVGAnimatedLength": ("AnimatedLength",),
    "SVGAnimatedLengthList": ("AnimatedLengthList",),
    "SVGAnimatedNumberList": ("AnimatedNumberList",),
    "SVGAnimatedTransformList": ("AnimatedTransformList",),
    "SVGAnimatedRect": ("AnimatedRect",),
    "SVGAnimatedEnumeration": ("AnimatedEnumeration",),
    "SVGAnimatedNumber": ("AnimatedNumber",),
    "SVGAnimatedInteger": ("AnimatedInteger",),
    "SVGAnimatedString": ("AnimatedString",),
    "SVGList": ("LengthList", "NumberList", "TransformList"),
    "SVGDecodedImageData": ("DecodedImageData",),
    "SVGFitToViewBox": ("FitToViewBox",),
    "SVGTextPositioningElement": ("TextPositioning", "Element"),
    "SVGLinearGradientElement": ("LinearGradient", "Element"),
    "SVGRadialGradientElement": ("LinkedRadialGradient", "RadialGradient", "Element"),
    "SVGPatternElement": ("Pattern", "Element"),
    "SVGComponentTransferFunctionElement": ("ComponentTransfer", "Element"),
    "SVGFilterPrimitiveStandardAttributes": ("FilterPrimitive", "Element"),
}

for _svg_element_owner in (
    "SVGAElement", "SVGCircleElement", "SVGClipPathElement", "SVGDefsElement",
    "SVGDescElement", "SVGElement", "SVGEllipseElement", "SVGFEBlendElement",
    "SVGFEColorMatrixElement", "SVGFEComponentTransferElement", "SVGFECompositeElement",
    "SVGFEDisplacementMapElement", "SVGFEDropShadowElement", "SVGFEFloodElement",
    "SVGFEGaussianBlurElement", "SVGFEImageElement", "SVGFEMergeNodeElement",
    "SVGFEMorphologyElement", "SVGFEOffsetElement", "SVGFETurbulenceElement",
    "SVGFilterElement", "SVGForeignObjectElement", "SVGGElement", "SVGGeometryElement",
    "SVGGradientElement", "SVGGraphicsElement", "SVGImageElement", "SVGLineElement",
    "SVGMaskElement", "SVGMetadataElement", "SVGPathElement", "SVGPolygonElement",
    "SVGPolylineElement", "SVGRectElement", "SVGScriptElement", "SVGSVGElement",
    "SVGStopElement", "SVGStyleElement", "SVGSymbolElement", "SVGTSpanElement",
    "SVGTextContentElement", "SVGTextElement", "SVGTextPathElement", "SVGTitleElement",
    "SVGURIReferenceMixin", "SVGUseElement", "SVGViewElement",
):
    CONSOLIDATED_OWNER_ALIASES[_svg_element_owner] = ("Element",)

CONSOLIDATED_OWNER_ALIASES["SVGSVGElement"] = ("Element", "SvgViewport")

for _css_rule_owner in (
    "CSSRule", "CSSConditionRule", "CSSGroupingRule", "CSSImportRule",
    "CSSKeyframeRule", "CSSKeyframesRule", "CSSLayerBlockRule",
    "CSSLayerStatementRule", "CSSMarginRule", "CSSMediaRule",
    "CSSNamespaceRule", "CSSNestedDeclarations", "CSSPageRule",
    "CSSPropertyRule", "CSSStyleRule", "CSSSupportsRule", "CSSFontFaceRule",
):
    CONSOLIDATED_OWNER_ALIASES[_css_rule_owner] = ("CSSRule",)

for _css_calculation_owner in (
    "CalculationNode", "NumericCalculationNode", "RandomCalculationNode",
    "Negate", "Invert", "Min", "Max", "Clamp", "Round", "Sum", "Product",
    "Abs", "Sign", "Sin", "Cos", "Tan", "Asin", "Acos", "Atan", "Atan2",
    "Pow", "Sqrt", "Hypot", "Log", "Exp", "Mod", "Rem", "NonMathFunction",
    "CalculationResult", "CalculatedStyleValue",
):
    CONSOLIDATED_OWNER_ALIASES[_css_calculation_owner] = (
        "CalcNode", "CalculatedStyleValue", "CalcResult", "NumericType"
    )

# Class-qualified implementations that must use a different V owner because
# the C++ class name is reserved or the translated representation is shared.
CONSOLIDATED_METHOD_MAPPINGS: dict[tuple[str, str], tuple[tuple[str, str | None], ...]] = {
    # Macro/variant constructor spellings are not valid V method identifiers;
    # they map to the equivalent tagged-value operations.
    ("StyleValue", "__ENUMERATE_CSS_STYLE_VALUE_TYPE"): (("type_", "StyleValue"),),
    ("ComponentValue", "Token"): (("from_token", "ComponentValue"),),
    # CSS owns ComputedProperties in the V module graph, so the SVG class
    # overrides are dispatched together at the style-computation boundary.
    ("SVGElement", "adjust_computed_style"): (("adjust_element_computed_style", None),),
    ("SVGSymbolElement", "adjust_computed_style"): (("adjust_element_computed_style", None),),
    # Primitive calculated-value resolution receives Layout's already-derived
    # length context explicitly in V, avoiding a CSS -> Layout module cycle.
    ("Angle", "resolve_calculated"): (("resolve_calculated_with_context", "Angle"),),
    ("Frequency", "resolve_calculated"): (("resolve_calculated_with_context", "Frequency"),),
    ("Time", "resolve_calculated"): (("resolve_calculated_with_context", "Time"),),
    # These C++ class-private helpers are module-private free functions in V;
    # their callers and tests exercise the same algorithms directly.
    ("CSSLayerBlockRule", "next_unique_anonymous_layer_name"): (
        ("next_unique_anonymous_layer_name", None),
    ),
    ("FontComputer", "find_matching_font_weight_ascending"): (
        ("find_matching_font_weight_ascending", None),
    ),
    ("FontComputer", "find_matching_font_weight_descending"): (
        ("find_matching_font_weight_descending", None),
    ),
    ("Selector", "collect_ancestor_hashes"): (("selector_ancestor_hashes", None),),
    # Renderer-independent painting keeps these algorithms on value records or
    # as free helpers instead of mirroring the backend-owned C++ class tree.
    ("CornerRadii", "adjust_corners_for_spread_distance"): (
        ("adjust_for_spread_distance", "CornerRadii"),
    ),
    ("InputColors", "get_shade"): (("get_shade", None),),
    ("FieldSetPaintable", "paint_background"): (
        ("background_clip_rect", "FieldSetPaintable"),
    ),
    # SVG formatting stores the computed paint transforms and geometry beside
    # the other used layout values. Painting consumes these same values rather
    # than copying them into a parallel paintable-class hierarchy.
    ("ComputedTransforms", "svg_to_viewbox_transform"): (
        ("svg_viewbox_transform", "UsedValues"),
    ),
    ("ComputedTransforms", "svg_transform"): (("svg_transform", "UsedValues"),),
    ("SVGGraphicsPaintable", "set_computed_transforms"): (
        ("set_computed_svg_transforms", "UsedValues"),
    ),
    ("SVGPathPaintable", "set_computed_path"): (
        ("set_computed_svg_path", "UsedValues"),
    ),
    ("SVGPathPaintable", "computed_path"): (("computed_svg_path", "UsedValues"),),
    # Paint-server factory construction is folded into Layout's resource
    # resolution boundary, which returns the concrete Painting value record.
    ("SVGLinearGradientPaintStyle", "create"): (
        ("resolve_svg_linear_gradient_paint_style", None),
    ),
    ("SVGRadialGradientPaintStyle", "create"): (
        ("resolve_svg_radial_gradient_paint_style", None),
    ),
    ("SVGPatternPaintStyle", "create"): (("resolve_svg_pattern_paint_style", None),),
    # `Error` is V's built-in error interface. The concrete protocol error is
    # therefore named WebDriverError while retaining both upstream factories.
    ("Error", "from_code"): (
        ("from_code", "WebDriverError"),
        ("from_code_with_data", "WebDriverError"),
    ),
    # V names cannot contain an uppercase character after the first word.
    ("AnalyserNode", "conversion_to_dB"): (("conversion_to_d_b", "AnalyserNode"),),
    # PaintableWithLines is materialized as the active renderer's BlockBox
    # transport to avoid a Painting -> Layout module cycle. These complete
    # methods therefore remain source-shaped functions over that box.
    ("PaintableWithLines", "fragment_at_position"): (("fragment_at_position", None),),
    ("PaintableWithLines", "paint_cursor"): (("paint_cursor", None),),
    ("PaintableWithLines", "hit_test"): (("viewport_hit_test", None),),
    ("PaintableWithLines", "hit_test_fragments"): (
        ("compatibility_hit_test_fragments", None),
    ),
    ("PaintableBox", "hit_test_chrome"): (("compatibility_hit_test_chrome", None),),
    ("PaintableBox", "resizer_contains"): (("compatibility_resizer_contains", "BlockBox"),),
    ("ResizeHandle", "contains"): (("compatibility_resizer_contains", "BlockBox"),),
    # AudioScheduledSourceNode is the shared AudioNode state in the value-model
    # translation; its six operations remain concrete AudioNode methods.
    ("AudioScheduledSourceNode", "onended"): (("onended", "AudioNode"),),
    ("AudioScheduledSourceNode", "set_onended"): (("set_onended", "AudioNode"),),
    ("AudioScheduledSourceNode", "start"): (("start", "AudioNode"),),
    ("AudioScheduledSourceNode", "stop"): (("stop", "AudioNode"),),
    ("AudioScheduledSourceNode", "source_started"): (("source_started", "AudioNode"),),
    ("AudioScheduledSourceNode", "set_source_started"): (("set_source_started", "AudioNode"),),
    # DOM mixins are embedded directly into Node in the V object model.
    ("ChildNode", "before"): (("before", "Node"),),
    ("ChildNode", "after"): (("after", "Node"),),
    ("ChildNode", "replace_with"): (("replace_with", "Node"),),
    ("ChildNode", "remove_binding"): (("remove_binding", "Node"),),
    ("ChildNode", "viable_previous_sibling_for_insertion"): (
        ("viable_previous_sibling_for_insertion", "Node"),
    ),
    ("ChildNode", "viable_next_sibling_for_insertion"): (
        ("viable_next_sibling_for_insertion", "Node"),
    ),
    ("NonDocumentTypeChildNode", "previous_element_sibling"): (
        ("previous_element_sibling", "Node"),
    ),
    ("NonDocumentTypeChildNode", "previous_element_in_pre_order"): (
        ("previous_element_in_pre_order", "Node"),
    ),
    ("NonDocumentTypeChildNode", "next_element_sibling"): (
        ("next_element_sibling", "Node"),
    ),
    ("NonDocumentTypeChildNode", "next_element_in_pre_order"): (
        ("next_element_in_pre_order", "Node"),
    ),
    ("SlottableMixin", "assigned_slot"): (("assigned_slot", "Node"),),
    ("SlottableMixin", "slottable_name"): (("slottable_name", "Node"),),
    ("SlottableMixin", "set_slottable_name"): (("set_slottable_name", "Node"),),
    ("SlottableMixin", "assigned_slot_internal"): (("assigned_slot_internal", "Node"),),
    ("SlottableMixin", "set_assigned_slot"): (("set_assigned_slot", "Node"),),
    ("SlottableMixin", "manual_slot_assignment"): (("manual_slot_assignment", "Node"),),
    ("SlottableMixin", "set_manual_slot_assignment"): (
        ("set_manual_slot_assignment", "Node"),
    ),
    # SourceSnapshotParams is an HTML type. Importing HTML from DOM would make
    # the module graph cyclic, so the complete Document algorithm lives on the
    # HTML side and takes its source Document explicitly.
    ("Document", "snapshot_source_snapshot_params"): (
        ("snapshot_source_snapshot_params", None),
    ),
    # PseudoElement is already the public CSS pseudo-element enum in V, so the
    # backing object uses the unambiguous PseudoElement_ name.
    ("PseudoElement", "counters_set"): (("counters_set", "PseudoElement_"),),
    ("PseudoElement", "ensure_counters_set"): (("ensure_counters_set", "PseudoElement_"),),
    ("PseudoElement", "set_counters_set"): (("set_counters_set", "PseudoElement_"),),
    ("PseudoElement", "layout_node"): (("layout_node", "PseudoElement_"),),
    ("PseudoElement", "unsafe_layout_node"): (("unsafe_layout_node", "PseudoElement_"),),
    ("PseudoElement", "set_layout_node"): (("set_layout_node", "PseudoElement_"),),
    ("PseudoElement", "cascaded_properties"): (("cascaded_properties", "PseudoElement_"),),
    ("PseudoElement", "set_cascaded_properties"): (
        ("set_cascaded_properties", "PseudoElement_"),
    ),
    ("PseudoElement", "computed_properties"): (("computed_properties", "PseudoElement_"),),
    ("PseudoElement", "set_computed_properties"): (
        ("set_computed_properties", "PseudoElement_"),
    ),
    ("PseudoElement", "custom_property_data"): (("custom_property_data", "PseudoElement_"),),
    ("PseudoElement", "set_custom_property_data"): (
        ("set_custom_property_data", "PseudoElement_"),
    ),
    ("PseudoElement", "has_non_empty_counters_set"): (
        ("has_non_empty_counters_set", "PseudoElement_"),
    ),
    ("PseudoElement", "scroll_offset"): (("scroll_offset", "PseudoElement_"),),
    ("PseudoElement", "set_scroll_offset"): (("set_scroll_offset", "PseudoElement_"),),
    ("Impl", "make_internal_string"): (("make_internal_string", "QualifiedName"),),
    # Fetch has distinct Web-facing Request/Response objects and infrastructure
    # records with the same C++ class names. V names the Web-facing wrappers
    # RequestObject/ResponseObject and consolidates filtered response subclasses
    # into Response while retaining their concrete filtering algorithms.
    ("BodyMixin", "body"): (("body_stream", "BodyMixin"),),
    ("Request", "mime_type_impl"): (("mime_type_impl", "RequestObject"),),
    ("Request", "body_impl"): (("body_impl", "RequestObject"),),
    ("Request", "construct_impl"): (("construct_impl", "RequestObject"),),
    ("Request", "headers"): (("headers", "RequestObject"),),
    ("Request", "cache"): (("cache", "RequestObject"),),
    ("Request", "redirect"): (("redirect", "RequestObject"),),
    ("Request", "integrity"): (("integrity", "RequestObject"),),
    ("Request", "is_reload_navigation"): (("is_reload_navigation", "RequestObject"),),
    ("Request", "is_history_navigation"): (("is_history_navigation", "RequestObject"),),
    ("Request", "signal"): (("signal", "RequestObject"),),
    ("Request", "duplex"): (("duplex", "RequestObject"),),
    ("Request", "as_platform_object"): (("as_platform_object", "RequestObject"),),
    ("Response", "mime_type_impl"): (("mime_type_impl", "ResponseObject"),),
    ("Response", "body_impl"): (("body_impl", "ResponseObject"),),
    ("Response", "initialize_response"): (("initialize_response", "ResponseObject"),),
    ("Response", "construct_impl"): (("construct_impl", "ResponseObject"),),
    ("Response", "redirect"): (("redirect", "ResponseObject"),),
    ("Response", "json"): (("json", "ResponseObject"),),
    ("Response", "redirected"): (("redirected", "ResponseObject"),),
    ("Response", "ok"): (("ok", "ResponseObject"),),
    ("Response", "status_text"): (("status_text", "ResponseObject"),),
    ("Response", "headers"): (("headers", "ResponseObject"),),
    ("Response", "as_platform_object"): (("as_platform_object", "ResponseObject"),),
    ("FilteredResponse", "type"): (("fetch_response_type", "Response"),),
    ("FilteredResponse", "aborted"): (("fetch_response_aborted", "Response"),),
    ("FilteredResponse", "set_aborted"): (("set_aborted", "Response"),),
    ("FilteredResponse", "url_list"): (("fetch_response_url_list", "Response"),),
    ("FilteredResponse", "set_url_list"): (("set_url_list", "Response"),),
    ("FilteredResponse", "status"): (("fetch_response_status", "Response"),),
    ("FilteredResponse", "set_status"): (("set_status", "Response"),),
    ("FilteredResponse", "status_message"): (("fetch_response_status_message", "Response"),),
    ("FilteredResponse", "set_status_message"): (("set_status_message", "Response"),),
    ("FilteredResponse", "header_list"): (("fetch_response_header_list", "Response"),),
    ("FilteredResponse", "set_header_list"): (("set_header_list", "Response"),),
    ("FilteredResponse", "body"): (("fetch_response_body", "Response"),),
    ("FilteredResponse", "set_body"): (("set_body", "Response"),),
    ("FilteredResponse", "cache_state"): (("fetch_response_cache_state", "Response"),),
    ("FilteredResponse", "set_cache_state"): (("set_cache_state", "Response"),),
    ("FilteredResponse", "cors_exposed_header_name_list"): (("fetch_response_cors_exposed_header_name_list", "Response"),),
    ("FilteredResponse", "set_cors_exposed_header_name_list"): (("set_cors_exposed_header_name_list", "Response"),),
    ("FilteredResponse", "range_requested"): (("fetch_response_range_requested", "Response"),),
    ("FilteredResponse", "set_range_requested"): (("set_range_requested", "Response"),),
    ("FilteredResponse", "request_includes_credentials"): (("fetch_response_request_includes_credentials", "Response"),),
    ("FilteredResponse", "set_request_includes_credentials"): (("set_request_includes_credentials", "Response"),),
    ("FilteredResponse", "timing_allow_passed"): (("fetch_response_timing_allow_passed", "Response"),),
    ("FilteredResponse", "set_timing_allow_passed"): (("set_timing_allow_passed", "Response"),),
    ("FilteredResponse", "body_info"): (("fetch_response_body_info", "Response"),),
    ("FilteredResponse", "set_body_info"): (("set_body_info", "Response"),),
    ("FilteredResponse", "internal_response"): (("internal_response", "Response"),),
    ("BasicFilteredResponse", "create"): (("create_basic_filtered_response", "Response"),),
    ("BasicFilteredResponse", "type"): (("fetch_response_type", "Response"),),
    ("BasicFilteredResponse", "header_list"): (("fetch_response_header_list", "Response"),),
    ("CORSFilteredResponse", "create"): (("create_cors_filtered_response", "Response"),),
    ("CORSFilteredResponse", "type"): (("fetch_response_type", "Response"),),
    ("CORSFilteredResponse", "header_list"): (("fetch_response_header_list", "Response"),),
    ("OpaqueFilteredResponse", "create"): (("create_opaque_filtered_response", "Response"),),
    ("OpaqueFilteredResponse", "type"): (("fetch_response_type", "Response"),),
    ("OpaqueFilteredResponse", "url_list"): (("fetch_response_url_list", "Response"),),
    ("OpaqueFilteredResponse", "status"): (("fetch_response_status", "Response"),),
    ("OpaqueFilteredResponse", "status_message"): (("fetch_response_status_message", "Response"),),
    ("OpaqueFilteredResponse", "header_list"): (("fetch_response_header_list", "Response"),),
    ("OpaqueFilteredResponse", "body"): (("fetch_response_body", "Response"),),
    ("OpaqueRedirectFilteredResponse", "create"): (("create_opaque_redirect_filtered_response", "Response"),),
    ("OpaqueRedirectFilteredResponse", "type"): (("fetch_response_type", "Response"),),
    ("OpaqueRedirectFilteredResponse", "status"): (("fetch_response_status", "Response"),),
    ("OpaqueRedirectFilteredResponse", "status_message"): (("fetch_response_status_message", "Response"),),
    ("OpaqueRedirectFilteredResponse", "header_list"): (("fetch_response_header_list", "Response"),),
    ("OpaqueRedirectFilteredResponse", "body"): (("fetch_response_body", "Response"),),
    # IndexedDB internal records use Data suffixes to distinguish them from
    # Web-facing handles with the same conceptual names.
    ("IDBCursorWithValue", "value"): (("idb_cursor_with_value_value", "IDBCursor"),),
    ("Database", "for_each_database"): (("for_each_database", "DatabaseData"),),
    ("Database", "create"): (("create", "DatabaseData"),),
    ("Database", "object_store_with_name"): (("object_store_with_name", "DatabaseData"),),
    ("Database", "for_key"): (("for_key", "DatabaseData"),),
    ("Database", "for_key_and_name"): (("for_key_and_name", "DatabaseData"),),
    ("Database", "create_for_key_and_name"): (("create_for_key_and_name", "DatabaseData"),),
    ("Database", "delete_for_key_and_name"): (("delete_for_key_and_name", "DatabaseData"),),
    ("Database", "associated_connections_as_heap_vector"): (("associated_connections_as_heap_vector", "DatabaseData"),),
    ("Database", "associated_connections_as_root_vector"): (("associated_connections_as_root_vector", "DatabaseData"),),
    ("Database", "associated_connections_as_heap_vector_except"): (("associated_connections_as_heap_vector_except", "DatabaseData"),),
    ("Database", "wait_for_connections_to_close"): (("wait_for_connections_to_close", "DatabaseData"),),
    ("Database", "check_pending_connection_wait"): (("check_pending_connection_wait", "DatabaseData"),),
    ("Database", "set_version"): (("set_version", "DatabaseData"),),
    ("Database", "version"): (("database_version", "DatabaseData"),),
    ("Database", "name"): (("database_name", "DatabaseData"),),
    ("Database", "set_upgrade_transaction"): (("set_upgrade_transaction", "DatabaseData"),),
    ("Database", "upgrade_transaction"): (("upgrade_transaction", "DatabaseData"),),
    ("Database", "associate"): (("associate", "DatabaseData"),),
    ("Database", "object_stores"): (("object_stores", "DatabaseData"),),
    ("Database", "add_object_store"): (("add_object_store", "DatabaseData"),),
    ("Database", "remove_object_store"): (("remove_object_store", "DatabaseData"),),
    ("ObjectStore", "create"): (("create", "ObjectStoreData"),),
    ("ObjectStore", "mutation_log_position"): (("mutation_log_position", "ObjectStoreData"),),
    ("ObjectStore", "revert_mutations_from"): (("revert_mutations_from", "ObjectStoreData"),),
    ("ObjectStore", "remove_records_in_range"): (("remove_records_in_range", "ObjectStoreData"),),
    ("ObjectStore", "remove_record_with_key"): (("remove_record_with_key", "ObjectStoreData"),),
    ("ObjectStore", "has_record_with_key"): (("has_record_with_key", "ObjectStoreData"),),
    ("ObjectStore", "store_a_record"): (("store_a_record", "ObjectStoreData"),),
    ("ObjectStore", "count_records_in_range"): (("count_records_in_range", "ObjectStoreData"),),
    ("ObjectStore", "first_in_range"): (("first_in_range", "ObjectStoreData"),),
    ("ObjectStore", "clear_records"): (("clear_records", "ObjectStoreData"),),
    ("ObjectStore", "generate_a_key"): (("generate_a_key", "ObjectStoreData"),),
    ("ObjectStore", "possibly_update_the_key_generator"): (("possibly_update_the_key_generator", "ObjectStoreData"),),
    ("ObjectStore", "first_n_in_range"): (("first_n_in_range", "ObjectStoreData"),),
    ("ObjectStore", "last_n_in_range"): (("last_n_in_range", "ObjectStoreData"),),
    ("ObjectStore", "name"): (("object_store_name", "ObjectStoreData"),),
    ("ObjectStore", "set_name"): (("set_name", "ObjectStoreData"),),
    ("ObjectStore", "key_path"): (("object_store_key_path", "ObjectStoreData"),),
    ("ObjectStore", "uses_inline_keys"): (("uses_inline_keys", "ObjectStoreData"),),
    ("ObjectStore", "uses_out_of_line_keys"): (("uses_out_of_line_keys", "ObjectStoreData"),),
    ("ObjectStore", "key_generator"): (("key_generator", "ObjectStoreData"),),
    ("ObjectStore", "uses_a_key_generator"): (("uses_a_key_generator", "ObjectStoreData"),),
    ("ObjectStore", "index_set"): (("object_store_index_set", "ObjectStoreData"),),
    ("ObjectStore", "is_deleted"): (("is_deleted", "ObjectStoreData"),),
    ("ObjectStore", "set_deleted"): (("set_deleted", "ObjectStoreData"),),
    ("ObjectStore", "database"): (("database", "ObjectStoreData"),),
    ("ObjectStore", "records"): (("object_store_records", "ObjectStoreData"),),
    ("ObjectStore", "mutation_log"): (("mutation_log", "ObjectStoreData"),),
    ("ObjectStore", "set_mutation_log"): (("set_mutation_log", "ObjectStoreData"),),
    ("Index", "create"): (("create", "IndexData"),),
    ("Index", "set_name"): (("set_name", "IndexData"),),
    ("Index", "has_record_with_key"): (("has_record_with_key", "IndexData"),),
    ("Index", "referenced_value"): (("referenced_value", "IndexData"),),
    ("Index", "clear_records"): (("clear_records", "IndexData"),),
    ("Index", "first_in_range"): (("first_in_range", "IndexData"),),
    ("Index", "first_n_in_range"): (("first_n_in_range", "IndexData"),),
    ("Index", "last_n_in_range"): (("last_n_in_range", "IndexData"),),
    ("Index", "count_records_in_range"): (("count_records_in_range", "IndexData"),),
    ("Index", "store_a_record"): (("store_a_record", "IndexData"),),
    ("Index", "remove_record"): (("remove_record", "IndexData"),),
    ("Index", "remove_records_with_value_in_range"): (("remove_records_with_value_in_range", "IndexData"),),
    ("Index", "name"): (("index_name", "IndexData"),),
    ("Index", "unique"): (("index_unique", "IndexData"),),
    ("Index", "multi_entry"): (("index_multi_entry", "IndexData"),),
    ("Index", "object_store"): (("object_store", "IndexData"),),
    ("Index", "records"): (("index_records", "IndexData"),),
    ("Index", "key_path"): (("index_key_path", "IndexData"),),
    ("Index", "is_deleted"): (("is_deleted", "IndexData"),),
    ("Index", "set_deleted"): (("set_deleted", "IndexData"),),
    # Streams stores the generic-reader mixin directly in both concrete reader
    # records and represents the generic transform mixin with its public typed
    # wrapper. ReadableStream's controller union is exposed as two type-safe V
    # setters instead of an untagged base-class pointer.
    ("GenericTransformStreamMixin", "readable"): (("readable", "GenericTransformStream"),),
    ("GenericTransformStreamMixin", "writable"): (("writable", "GenericTransformStream"),),
    ("ReadableStream", "set_controller"): (
        ("set_default_controller", "ReadableStream"),
        ("set_byte_controller", "ReadableStream"),
    ),
    ("ReadableStreamGenericReaderMixin", "closed"): (
        ("closed", "ReadableStreamDefaultReader"),
        ("closed", "ReadableStreamBYOBReader"),
    ),
    ("ReadableStreamGenericReaderMixin", "cancel"): (
        ("cancel", "ReadableStreamDefaultReader"),
        ("cancel", "ReadableStreamBYOBReader"),
    ),
    ("ReadableStreamGenericReaderMixin", "stream"): (
        ("reader_stream", "ReadableStreamDefaultReader"),
        ("byob_reader_stream", "ReadableStreamBYOBReader"),
    ),
    ("ReadableStreamGenericReaderMixin", "set_stream"): (
        ("set_reader_stream", "ReadableStreamDefaultReader"),
        ("set_byob_reader_stream", "ReadableStreamBYOBReader"),
    ),
    ("ReadableStreamGenericReaderMixin", "closed_promise_capability"): (
        ("closed_promise_capability", "ReadableStreamDefaultReader"),
        ("byob_closed_promise_capability", "ReadableStreamBYOBReader"),
    ),
    ("ReadableStreamGenericReaderMixin", "set_closed_promise_capability"): (
        ("set_closed_promise_capability", "ReadableStreamDefaultReader"),
        ("set_byob_closed_promise_capability", "ReadableStreamBYOBReader"),
    ),
    # Streams uses synchronously observable promise records. The private C++
    # request callback classes therefore collapse into the pumps which inspect
    # promise settlement and run the same chunk/close/error branches.
    ("ReadLoopReadRequest", "on_chunk"): (("read_all_bytes", "ReadableStreamDefaultReader"),),
    ("ReadLoopReadRequest", "on_close"): (("read_all_bytes", "ReadableStreamDefaultReader"),),
    ("ReadLoopReadRequest", "on_error"): (("read_all_bytes", "ReadableStreamDefaultReader"),),
    ("ReadableStreamDefaultReader", "read_a_chunk"): (("readable_stream_default_reader_read", None),),
    ("ReadableStreamPipeTo", "process"): (("pump_readable_pipe", None),),
    ("ReadableStreamPipeTo", "set_abort_signal"): (("pipe_to", "ReadableStream"),),
    ("ReadableStreamPipeTo", "shutdown_with_action"): (("pump_readable_pipe", None),),
    ("ReadableStreamPipeTo", "shutdown"): (("pump_readable_pipe", None),),
    ("ReadableStreamPipeTo", "read_chunk"): (("pump_readable_pipe", None),),
    ("ReadableStreamPipeTo", "write_chunk"): (("pump_readable_pipe", None),),
    ("ReadableStreamPipeTo", "write_unwritten_chunks"): (("pump_readable_pipe", None),),
    ("ReadableStreamPipeTo", "wait_for_pending_writes_to_complete"): (("pump_readable_pipe", None),),
    ("ReadableStreamPipeTo", "finish"): (("finish_pipe", None), ("fail_pipe", None)),
    ("ReadableStreamPipeTo", "check_for_error_and_close_states"): (("pump_readable_pipe", None),),
    ("ReadableStreamPipeTo", "check_for_forward_errors"): (("pump_readable_pipe", None),),
    ("ReadableStreamPipeTo", "check_for_backward_errors"): (("pump_readable_pipe", None),),
    ("ReadableStreamPipeTo", "check_for_forward_close"): (("pump_readable_pipe", None),),
    ("ReadableStreamPipeTo", "check_for_backward_close"): (("pump_readable_pipe", None),),
    ("ReadableStreamTeeReadRequest", "on_chunk"): (("pump_readable_tee_source", None),),
    ("ReadableStreamTeeReadRequest", "on_close"): (("close_tee_branches", None),),
    ("ReadableStreamTeeReadRequest", "on_error"): (("error_tee_branches", None),),
    ("ReadableByteStreamTeeDefaultReadRequest", "on_chunk"): (("pump_readable_byte_tee_source", None),),
    ("ReadableByteStreamTeeDefaultReadRequest", "on_close"): (("close_tee_branches", None),),
    ("ReadableByteStreamTeeDefaultReadRequest", "on_error"): (("error_tee_branches", None),),
    ("ReadableByteStreamTeeBYOBReadRequest", "on_chunk"): (("pump_readable_byte_tee_source", None),),
    ("ReadableByteStreamTeeBYOBReadRequest", "on_close"): (("close_byte_tee_branches_after_byob_read", None),),
    ("ReadableByteStreamTeeBYOBReadRequest", "on_error"): (("error_tee_branches", None),),
}

# Inline C++ accessors whose state is deliberately exposed as a typed public V
# record field. These mappings are accepted only while the named owner/field
# exists, just as function mappings fail open when their implementation moves.
CONSOLIDATED_FIELD_MAPPINGS: dict[
    tuple[str, str], tuple[tuple[str, str], ...]
] = {
    ("SVGGradientPaintStyle", "gradient_transform"): (("gradient_transform", "SVGGradientPaintStyle"),),
    ("SVGGradientPaintStyle", "set_gradient_transform"): (("gradient_transform", "SVGGradientPaintStyle"),),
    ("SVGGradientPaintStyle", "spread_method"): (("spread_method", "SVGGradientPaintStyle"),),
    ("SVGGradientPaintStyle", "set_spread_method"): (("spread_method", "SVGGradientPaintStyle"),),
    ("SVGGradientPaintStyle", "color_stops"): (("color_stops", "SVGGradientPaintStyle"),),
    ("SVGGradientPaintStyle", "repeat_length"): (("repeat_length", "SVGGradientPaintStyle"),),
    ("SVGGradientPaintStyle", "color_space"): (("color_space", "SVGGradientPaintStyle"),),
    ("SVGGradientPaintStyle", "set_color_space"): (("color_space", "SVGGradientPaintStyle"),),
    ("SVGLinearGradientPaintStyle", "start_point"): (("start_point", "SVGLinearGradientPaintStyle"),),
    ("SVGLinearGradientPaintStyle", "end_point"): (("end_point", "SVGLinearGradientPaintStyle"),),
    ("SVGLinearGradientPaintStyle", "set_start_point"): (("start_point", "SVGLinearGradientPaintStyle"),),
    ("SVGLinearGradientPaintStyle", "set_end_point"): (("end_point", "SVGLinearGradientPaintStyle"),),
    ("SVGRadialGradientPaintStyle", "start_center"): (("start_center", "SVGRadialGradientPaintStyle"),),
    ("SVGRadialGradientPaintStyle", "start_radius"): (("start_radius", "SVGRadialGradientPaintStyle"),),
    ("SVGRadialGradientPaintStyle", "end_center"): (("end_center", "SVGRadialGradientPaintStyle"),),
    ("SVGRadialGradientPaintStyle", "end_radius"): (("end_radius", "SVGRadialGradientPaintStyle"),),
    ("SVGRadialGradientPaintStyle", "set_start_center"): (("start_center", "SVGRadialGradientPaintStyle"),),
    ("SVGRadialGradientPaintStyle", "set_start_radius"): (("start_radius", "SVGRadialGradientPaintStyle"),),
    ("SVGRadialGradientPaintStyle", "set_end_center"): (("end_center", "SVGRadialGradientPaintStyle"),),
    ("SVGRadialGradientPaintStyle", "set_end_radius"): (("end_radius", "SVGRadialGradientPaintStyle"),),
    ("SVGPatternPaintStyle", "tile_display_list"): (("tile_display_list", "SVGPatternPaintStyle"),),
    ("SVGPatternPaintStyle", "tile_rect"): (("tile_rect", "SVGPatternPaintStyle"),),
    ("SVGPatternPaintStyle", "pattern_transform"): (("pattern_transform", "SVGPatternPaintStyle"),),
    # Paintable-class state that V retains on the layout result or on its
    # renderer-independent value record instead of behind trivial accessors.
    ("SVGGraphicsPaintable", "computed_transforms"): (
        ("svg_viewbox_transform_", "UsedValues"),
        ("svg_transform_", "UsedValues"),
    ),
    ("ViewportPaintable", "scroll_state_snapshot"): (
        ("scroll_state_snapshot", "DocumentLayoutResult"),
    ),
    ("ViewportPaintable", "visual_context_tree"): (
        ("visual_context_tree", "DocumentLayoutResult"),
    ),
    ("DisplayList", "visual_context_tree"): (("visual_context_tree", "DisplayList"),),
}

# Some V modules deliberately consolidate private C++ helpers into a shared
# implementation or give them a module-specific prefix to avoid collisions.
# These mappings are source-qualified and are accepted only while every named
# V target still exists, so they cannot silently turn stale documentation into
# coverage.
CONSOLIDATED_FUNCTION_MAPPINGS: dict[tuple[str, str], tuple[str, ...]] = {
    ("Interpolation.cpp", "slerp"): ("interpolation_slerp",),
    ("Interpolation.cpp", "length_percentage_or_auto_to_style_value"): ("interpolation_length_percentage_or_auto_to_style_value",),
    ("StyleComputer.cpp", "filter_namespace_rule"): ("style_scope_filter_namespace_rule",),
    ("StyleComputer.cpp", "is_roundabout_selector_bucketable_as_something_simpler"): ("style_scope_is_roundabout_selector_bucketable_as_something_simpler",),
    ("StyleComputer.cpp", "line_width_keyword_to_css_pixels"): ("computed_interpolation_line_width_keyword_to_css_pixels",),
    ("StyleComputer.cpp", "snap_a_length_as_a_border_width"): ("computed_interpolation_snap_a_length_as_a_border_width",),
    ("StyleComputer.cpp", "compute_style_value_list"): ("computed_interpolation_compute_style_value_list",),
    ("Serialize.cpp", "needs_comment_between"): ("component_values_need_comment_between",),
    ("StyleInvalidation.cpp", "is_stacking_context_creating_value"): (
        "is_stacking_context_creating_value_boundary",
    ),
    ("StyleInvalidationData.cpp", "for_each_consecutive_simple_selector_group"): (
        "selector_groups_for_invalidation",
    ),
    ("StyleValues/BasicShapeStyleValue.cpp", "path_from_resolved_rect"): ("style_values_extra_path_from_resolved_rect",),
    ("StyleValues/RadialSizeStyleValue.cpp", "side_shape"): ("style_values_extra_side_shape",),
    ("StyleValues/RadialSizeStyleValue.cpp", "closest_side_shape"): ("style_values_extra_closest_side_shape",),
    ("StyleValues/RadialSizeStyleValue.cpp", "farthest_side_shape"): ("style_values_extra_farthest_side_shape",),
    ("StyleValues/RadialSizeStyleValue.cpp", "corner_distance"): ("style_values_extra_corner_distance",),
    ("StyleValues/RadialSizeStyleValue.cpp", "ellipse_corner_shape"): ("style_values_extra_ellipse_corner_shape",),
    ("Parser/Tokenizer.cpp", "is_E"): ("is_e",),
    ("CryptoAlgorithms.cpp", "parse_an_ASN1_structure"): ("parse_an_asn1_structure",),
    ("QualifiedName.cpp", "hash_impl"): ("qualified_name_hash_impl",),
    ("Enums.cpp", "from_bindings_enum"): (
        "from_bindings_referrer_policy",
        "from_bindings_request_mode",
        "from_bindings_request_credentials",
        "from_bindings_request_cache",
        "from_bindings_request_redirect",
        "from_bindings_request_priority",
    ),
    ("Enums.cpp", "to_bindings_enum"): (
        "to_bindings_referrer_policy",
        "to_bindings_request_destination",
        "to_bindings_request_mode",
        "to_bindings_request_credentials",
        "to_bindings_request_cache",
        "to_bindings_request_redirect",
        "to_bindings_response_type",
    ),
    ("BrowsingContext.cpp", "populate_with_html_head_body"): ("populate_with_html_head_and_body",),
    ("CanvasRenderingContext2D.cpp", "is_point_in_path_internal"): ("canvas_point_in_path_internal",),
    ("CrossOrigin/AbstractOperations.cpp", "cross_origin_get_own_property_helper"): ("get_own_property",),
    ("EmbedderPolicy.cpp", "embedder_policy_value_to_string"): ("to_string",),
    ("EventLoop/EventLoop.cpp", "run_when_event_loop_reaches_step_1"): ("run_upon_reaching_step_1",),
    ("FormAssociatedElement.cpp", "string_to_selection_direction"): ("selection_direction_from_string",),
    ("FormControlInfrastructure.cpp", "create_entry"): (
        "create_form_data_file_entry",
        "create_form_data_string_entry",
    ),
    ("HTMLFormElement.cpp", "method_attribute_to_method_state"): ("method_state",),
    ("HTMLFormElement.cpp", "encoding_type_attribute_to_encoding_type_state"): ("encoding_type",),
    ("HTMLFormElement.cpp", "is_listed_element"): ("html_form_element_is_listed",),
    ("HTMLFormElement.cpp", "is_form_control"): ("html_form_element_is_form_control",),
    ("HTMLFormElement.cpp", "convert_to_list_of_name_value_pairs"): ("html_form_name_value_pairs",),
    ("HTMLFormElement.cpp", "plain_text_encode"): ("html_form_plain_text_encode",),
    ("HTMLInputElement.cpp", "is_valid_simple_color"): ("valid_simple_color",),
    ("HTMLInputElement.cpp", "is_in_same_radio_button_group"): ("same_radio_group",),
    ("HTMLInputElement.cpp", "convert_month_string_to_number"): ("convert_string_to_number",),
    ("HTMLInputElement.cpp", "convert_week_string_to_number"): ("convert_string_to_number",),
    ("HTMLInputElement.cpp", "convert_date_string_to_number"): ("convert_string_to_number",),
    ("HTMLInputElement.cpp", "convert_local_date_and_time_string_to_number"): ("convert_string_to_number",),
    ("HTMLInputElement.cpp", "convert_number_to_month_string"): ("convert_number_to_string",),
    ("HTMLInputElement.cpp", "convert_date_to_month_string"): ("convert_number_to_string",),
    ("HTMLInputElement.cpp", "convert_number_to_week_string"): ("convert_number_to_string",),
    ("HTMLInputElement.cpp", "convert_number_to_date_string"): ("convert_number_to_string",),
    ("HTMLInputElement.cpp", "convert_number_to_time_string"): ("convert_number_to_string",),
    ("HTMLInputElement.cpp", "convert_number_to_local_date_and_time_string"): ("convert_number_to_string",),
    ("HTMLLinkElement.cpp", "translate_a_preload_destination"): ("translate_preload_destination",),
    ("HTMLLinkElement.cpp", "type_matches_destination"): ("link_type_matches_destination",),
    ("HTMLOptionElement.cpp", "concatenate_descendants_text_content"): ("append_option_descendant_text",),
    ("ImageBitmap.cpp", "create_bitmap_from_bitmap_data"): ("set_bitmap",),
    ("ImageBitmap.cpp", "deserialize_bitmap"): ("image_bitmap_deserialization_steps",),
    ("ImageData.cpp", "create_bitmap_backed_by_uint8_clamped_array"): ("image_data_initialize",),
    ("MessagePort.cpp", "all_message_ports"): ("for_each_message_port",),
    ("Navigable.cpp", "all_navigables"): ("all_navigable_models",),
    ("PotentialCORSRequest.cpp", "create_potential_CORS_request"): ("create_potential_cors_request",),
    ("SourceSet.cpp", "pixel_density"): ("image_source_pixel_density",),
    ("SourceSet.cpp", "collect_a_sequence_of_code_points"): ("collect_srcset_characters",),
    ("StructuredSerialize.cpp", "structured_deserialize_internal"): ("decode_value",),
    ("StructuredSerialize.cpp", "structured_serialize_internal"): ("serialize_value",),
    ("WindowOrWorkerGlobalScope.cpp", "crop_to_the_source_rectangle_with_formatting"): ("image_bitmap_crop_and_resize",),
    ("XMLSerializer.cpp", "add_prefix_to_namespace_prefix_map"): ("xml_add_prefix_to_namespace_prefix_map",),
    ("XMLSerializer.cpp", "retrieve_a_preferred_prefix_string"): ("xml_retrieve_a_preferred_prefix_string",),
    ("XMLSerializer.cpp", "generate_a_prefix"): ("xml_generate_a_prefix",),
    ("XMLSerializer.cpp", "prefix_is_in_prefix_map"): ("xml_prefix_is_in_prefix_map",),
    ("XMLSerializer.cpp", "record_namespace_information"): ("xml_record_namespace_information",),
    ("XMLSerializer.cpp", "serialize_an_attribute_value"): ("xml_serialize_an_attribute_value",),
    ("XMLSerializer.cpp", "serialize_element_attributes"): ("xml_serialize_element_attributes",),
    ("XMLSerializer.cpp", "serialize_element"): ("xml_serialize_element",),
    ("XMLSerializer.cpp", "serialize_document"): ("xml_serialize_document",),
    ("XMLSerializer.cpp", "serialize_comment"): ("xml_serialize_comment",),
    ("XMLSerializer.cpp", "serialize_text"): ("xml_serialize_text",),
    ("XMLSerializer.cpp", "serialize_document_fragment"): ("xml_serialize_document_fragment",),
    ("XMLSerializer.cpp", "serialize_document_type"): ("xml_serialize_document_type",),
    ("XMLSerializer.cpp", "serialize_processing_instruction"): ("xml_serialize_processing_instruction",),
    ("XMLSerializer.cpp", "serialize_cdata_section"): ("xml_serialize_cdata_section",),
}


@dataclass(frozen=True)
class UpstreamMethod:
    source: str
    line: int
    class_name: str
    name: str
    disposition: str
    candidate_v_functions: tuple[str, ...]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--ladybird",
        type=Path,
        default=Path.home() / "code/3rd/ladybird",
        help="Ladybird checkout containing Libraries/LibWeb/HTML",
    )
    parser.add_argument(
        "--translation",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="libweb_v checkout",
    )
    parser.add_argument("--json", action="store_true", help="emit the complete inventory as JSON")
    return parser.parse_args()


def v_function_names(translation: Path) -> set[tuple[str, str | None]]:
    functions: set[tuple[str, str | None]] = set()
    # Some LibWeb/HTML virtuals are necessarily implemented at a lower-layer
    # boundary in V to avoid module cycles (notably computed-style adjustment
    # in css and DOM event/node plumbing in dom).
    for module in ("html", "dom", "css", "layout", "bindings"):
        for source in (translation / module).glob("*.v"):
            if source.name.endswith("_test.v"):
                continue
            text = source.read_text()
            for match in V_FUNCTION.finditer(text):
                owner = match.group("associated")
                if receiver := match.group("receiver"):
                    receiver_type = receiver.split()[-1].lstrip("&?")
                    owner = receiver_type.split(".")[-1]
                functions.add((match.group("name"), owner))
            for interface in V_INTERFACE.finditer(text):
                owner = interface.group("name")
                for method in V_INTERFACE_METHOD.finditer(interface.group("body")):
                    functions.add((method.group("name"), owner))
    return functions


def v_field_names(translation: Path) -> set[tuple[str, str]]:
    fields: set[tuple[str, str]] = set()
    for source in translation.rglob("*.v"):
        if source.name.endswith("_test.v"):
            continue
        fields.update(v_field_names_in_text(source.read_text(errors="replace")))
    return fields


def strip_v_comments_and_literals(text: str) -> str:
    """Blank V comments and literals without changing offsets or newlines."""
    output = list(text)
    index = 0
    state = "code"
    quote = ""
    block_depth = 0
    while index < len(text):
        if state == "code":
            if text.startswith("//", index):
                output[index] = output[index + 1] = " "
                index += 2
                state = "line-comment"
                continue
            if text.startswith("/*", index):
                output[index] = output[index + 1] = " "
                index += 2
                state = "block-comment"
                block_depth = 1
                continue
            if text[index] in {'"', "'", "`"}:
                quote = text[index]
                output[index] = " "
                index += 1
                state = "literal"
                continue
            index += 1
            continue

        if state == "line-comment":
            if text[index] == "\n":
                state = "code"
            else:
                output[index] = " "
            index += 1
            continue

        if state == "block-comment":
            if text.startswith("/*", index):
                output[index] = output[index + 1] = " "
                block_depth += 1
                index += 2
                continue
            if text.startswith("*/", index):
                output[index] = output[index + 1] = " "
                block_depth -= 1
                index += 2
                if block_depth == 0:
                    state = "code"
                continue
            if text[index] != "\n":
                output[index] = " "
            index += 1
            continue

        if text[index] == "\\" and index + 1 < len(text):
            output[index] = " "
            if text[index + 1] != "\n":
                output[index + 1] = " "
            index += 2
            continue
        character = text[index]
        output[index] = "\n" if character == "\n" else " "
        index += 1
        if character == quote:
            state = "code"

    return "".join(output)


def v_field_names_in_text(text: str) -> set[tuple[str, str]]:
    sanitized = strip_v_comments_and_literals(text)

    fields: set[tuple[str, str]] = set()
    for struct_match in V_STRUCT.finditer(sanitized):
        owner = struct_match.group("name")
        opening = struct_match.end() - 1
        closing = matching_closing_brace(sanitized, opening)
        if closing is None:
            continue
        depth = 0
        for line in sanitized[opening + 1 : closing].splitlines():
            if depth == 0:
                if field_match := V_STRUCT_FIELD.match(line):
                    field_name = field_match.group("name")
                    if field_name not in {"pub", "mut"}:
                        fields.add((field_name, owner))
            depth += line.count("{") - line.count("}")
    return fields


def camel_to_snake(name: str) -> str:
    # Preserve the HTML prefix as its own word. The generic acronym rule sees
    # HTMLBRElement as the single acronym HTMLBR and produces htmlbr_element,
    # while translated DOM-backed helpers consistently use html_br_element.
    if match := re.match(r"HTML([A-Z]+)([A-Z][a-z].*)", name):
        acronym, remainder = match.groups()
        separator = "" if len(acronym) == 1 else "_"
        return "html_" + acronym.lower() + separator + camel_to_snake(remainder)
    with_acronyms_split = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1_\2", name)
    return re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", with_acronyms_split).lower()


def candidate_names(
    method_name: str, class_name: str, functions: set[tuple[str, str | None]]
) -> tuple[str, ...]:
    class_token = camel_to_snake(class_name)
    candidates: list[str] = []
    for name, owner in functions:
        normalized_owner = owner.removesuffix("Model") if owner else None
        owner_matches = normalized_owner == class_name or normalized_owner in CONSOLIDATED_OWNER_ALIASES.get(class_name, ())
        v_keyword_name = V_KEYWORD_METHODS.get(method_name)
        if owner_matches and (
            name == method_name
            or name.endswith("_" + method_name)
            or (v_keyword_name is not None and name == v_keyword_name)
        ):
            candidates.append(name)
            continue
        # DOM-backed algorithms conventionally put the translated class name
        # between the verb and the remainder of the C++ method name:
        # HTMLMeterElement::set_min -> set_html_meter_element_min.
        marker = class_token + "_"
        if marker in name and name.replace(marker, "", 1) == method_name:
            candidates.append(name)
    return tuple(sorted(candidates))


def free_function_candidate_names(
    function_name: str, functions: set[tuple[str, str | None]]
) -> tuple[str, ...]:
    v_name = V_KEYWORD_METHODS.get(function_name, function_name)
    return tuple(sorted({name for name, _ in functions if name == v_name}))


def mapped_field_candidate_names(
    method_name: str, class_name: str, fields: set[tuple[str, str]]
) -> tuple[str, ...]:
    mappings = CONSOLIDATED_FIELD_MAPPINGS.get((class_name, method_name), ())
    if not mappings or any(mapping not in fields for mapping in mappings):
        return ()
    return tuple(f"{owner}.{name}" for name, owner in mappings)


def method_inventory(
    upstream_html: Path,
    functions: set[tuple[str, str | None]],
    fields: set[tuple[str, str]] | None = None,
) -> list[UpstreamMethod]:
    fields = fields or set()
    inventory: list[UpstreamMethod] = []
    for source in sorted(upstream_html.rglob("*.cpp")):
        text = strip_cpp_comments(source.read_text(errors="replace"))
        for match in CPP_METHOD.finditer(text):
            opening = match.end() - 1
            if not is_function_definition_after_parameters(text, opening):
                continue
            class_name = match.group("class").split("::")[-1]
            method_name = match.group("name")
            candidates = candidate_names(method_name, class_name, functions)
            mapped_methods = CONSOLIDATED_METHOD_MAPPINGS.get((class_name, method_name), ())
            mapped_candidates = tuple(
                name for name, owner in mapped_methods if (name, owner) in functions
            )
            mapped_field_candidates = mapped_field_candidate_names(method_name, class_name, fields)
            if mapped_methods and len(mapped_candidates) == len(mapped_methods):
                candidates = mapped_candidates
                disposition = "consolidated-name-match"
            elif mapped_field_candidates:
                candidates = mapped_field_candidates
                disposition = "value-record-field-match"
            elif class_name in NAMESPACE_TEMPLATE_CLASSES:
                disposition = "namespace-template-specialization"
            elif method_name == "requires":
                disposition = "language-template-trait"
            elif class_name in LANGUAGE_TEMPLATE_TRAIT_CLASSES:
                disposition = "language-template-trait"
            elif method_name == class_name or method_name == "~" + class_name:
                disposition = "language-constructor-or-destructor"
            elif method_name in RUNTIME_ONLY_METHODS or (class_name, method_name) in BINDING_RUNTIME_METHODS:
                disposition = "gc-or-binding-runtime"
            elif method_name.startswith("operator"):
                disposition = "language-operator"
            elif candidates:
                disposition = "candidate-name-match"
            else:
                disposition = "unmatched"
            inventory.append(
                UpstreamMethod(
                    source=source.relative_to(upstream_html).as_posix(),
                    line=text.count("\n", 0, match.start()) + 1,
                    class_name=class_name,
                    name=method_name,
                    disposition=disposition,
                    candidate_v_functions=candidates,
                )
            )
    return inventory


def strip_cpp_comments(text: str) -> str:
    """Remove comments and literals while retaining stable source locations."""
    text = re.sub(r"/\*.*?\*/", lambda match: "\n" * match.group(0).count("\n"), text, flags=re.S)
    text = re.sub(r"//[^\n]*", lambda match: " " * len(match.group(0)), text)
    # Braces in diagnostics, URL strings, and character literals must not
    # perturb class/body depth. Preserve byte count and newlines so reported
    # locations still refer to the original header.
    literal = re.compile(r'R"[^ (\\\t\r\n]{0,16}\(.*?\)[^"\r\n]{0,16}"|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', re.S)
    return literal.sub(
        lambda match: "".join("\n" if char == "\n" else " " for char in match.group(0)),
        text,
    )


def matching_closing_brace(text: str, opening: int) -> int | None:
    depth = 0
    for index in range(opening, len(text)):
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                return index
    return None


def matching_closing_parenthesis(text: str, opening: int) -> int | None:
    depth = 0
    for index in range(opening, len(text)):
        if text[index] == "(":
            depth += 1
        elif text[index] == ")":
            depth -= 1
            if depth == 0:
                return index
    return None


def is_function_definition_after_parameters(text: str, opening: int) -> bool:
    """Return whether a candidate parameter list is followed by a body.

    Comments and literals have already been stripped. Parentheses in noexcept
    and requires clauses are skipped; a declaration or deleted/defaulted
    function reaches a semicolon before an opening body brace.
    """
    closing = matching_closing_parenthesis(text, opening)
    if closing is None:
        return False
    parenthesis_depth = 0
    for character in text[closing + 1 : closing + 1000]:
        if character == "(":
            parenthesis_depth += 1
        elif character == ")" and parenthesis_depth:
            parenthesis_depth -= 1
        elif parenthesis_depth == 0:
            if character == "{":
                return True
            if character in ";#":
                return False
    return False


def free_function_inventory(
    upstream_html: Path, functions: set[tuple[str, str | None]]
) -> list[UpstreamMethod]:
    """Inventory namespace-scope definitions in .cpp and .h sources.

    Ladybird keeps namespace-level definitions at column zero, while class
    members and function-body statements are indented. Qualified member
    definitions are excluded here because method_inventory covers .cpp files;
    qualified template specializations in headers are inventoried separately.
    """
    inventory: list[UpstreamMethod] = []
    for extension in ("*.cpp", "*.h"):
        for source in sorted(upstream_html.rglob(extension)):
            text = strip_cpp_comments(source.read_text(errors="replace"))
            for match in CPP_FREE_FUNCTION_HEAD.finditer(text):
                name_start = match.start("name")
                if text[max(0, name_start - 2) : name_start] == "::" or text[name_start - 1 : name_start] == "~":
                    continue
                opening = match.end() - 1
                if not is_function_definition_after_parameters(text, opening):
                    continue
                function_name = re.sub(r"\s+", "", match.group("name"))
                if function_name in {"alignof", "decltype", "noexcept", "requires", "sizeof"}:
                    continue
                if re.fullmatch(r"[A-Z][A-Z0-9_]*", function_name):
                    continue
                source_path = source.relative_to(upstream_html).as_posix()
                mapped_names = CONSOLIDATED_FUNCTION_MAPPINGS.get((source_path, function_name), ())
                available_names = {name for name, _ in functions}
                mapped_candidates = tuple(name for name in mapped_names if name in available_names)
                candidates = free_function_candidate_names(function_name, functions)
                if function_name.startswith("operator"):
                    disposition = "language-operator"
                elif mapped_names and len(mapped_candidates) == len(mapped_names):
                    candidates = mapped_candidates
                    disposition = "consolidated-name-match"
                elif candidates:
                    disposition = "candidate-name-match"
                else:
                    disposition = "unmatched"
                inventory.append(
                    UpstreamMethod(
                        source=source_path,
                        line=text.count("\n", 0, match.start()) + 1,
                        class_name="<namespace>",
                        name=function_name,
                        disposition=disposition,
                        candidate_v_functions=candidates,
                    )
                )
    return inventory


def qualified_header_template_inventory(upstream_html: Path) -> list[UpstreamMethod]:
    """Inventory out-of-class C++ template specializations in headers."""
    inventory: list[UpstreamMethod] = []
    for source in sorted(upstream_html.rglob("*.h")):
        text = strip_cpp_comments(source.read_text(errors="replace"))
        for match in HEADER_QUALIFIED_TEMPLATE_METHOD.finditer(text):
            inventory.append(
                UpstreamMethod(
                    source=source.relative_to(upstream_html).as_posix(),
                    line=text.count("\n", 0, match.start()) + 1,
                    class_name=match.group("class"),
                    name=match.group("name"),
                    disposition="namespace-template-specialization",
                    candidate_v_functions=(),
                )
            )
    return inventory


def header_inline_inventory(
    upstream_html: Path,
    functions: set[tuple[str, str | None]],
    fields: set[tuple[str, str]] | None = None,
) -> list[UpstreamMethod]:
    """Inventory methods implemented inline at class scope in HTML headers.

    This intentionally excludes declarations: out-of-line definitions are
    already inventoried from .cpp files, while pure declarations have no
    implementation to translate. Class-scope brace tracking keeps control-flow
    statements inside an inline method from being mistaken for more methods.
    """
    fields = fields or set()
    inventory: list[UpstreamMethod] = []
    for source in sorted(upstream_html.rglob("*.h")):
        text = strip_cpp_comments(source.read_text(errors="replace"))
        for class_match in HEADER_CLASS.finditer(text):
            # A specialization such as `struct AK::Formatter<T>` is a class
            # definition whose owner is Formatter, not AK. Retaining only the
            # final qualified component also lets the language-template-trait
            # classification below recognize these customization points.
            class_name = class_match.group("name").split("::")[-1]
            opening = class_match.end() - 1
            closing = matching_closing_brace(text, opening)
            if closing is None:
                continue

            # Scan only direct class scope. A candidate accumulates across
            # lines until its opening brace, so split declarations such as
            # `foo(...) const\n { ... }` are included. Method bodies and nested
            # classes are skipped as one balanced-brace region.
            depth = 0
            segment_start = opening + 1
            index = opening + 1
            while index < closing:
                character = text[index]
                if character == "{" and depth == 0:
                    candidate = text[segment_start : index + 1]
                    matches = list(HEADER_INLINE_METHOD.finditer(candidate))
                    if matches:
                        match = matches[-1]
                        method_name = match.group("name")
                        if re.fullmatch(r"[A-Z][A-Z0-9_]*", method_name):
                            body_end = matching_closing_brace(text, index)
                            if body_end is None:
                                break
                            index = body_end + 1
                            segment_start = index
                            continue
                        if not (method_name == "void" and "Function<void" in candidate):
                            candidates = candidate_names(method_name, class_name, functions)
                            mapped_methods = CONSOLIDATED_METHOD_MAPPINGS.get(
                                (class_name, method_name), ()
                            )
                            mapped_candidates = tuple(
                                name
                                for name, owner in mapped_methods
                                if (name, owner) in functions
                            )
                            mapped_field_candidates = mapped_field_candidate_names(
                                method_name, class_name, fields
                            )
                            if mapped_methods and len(mapped_candidates) == len(mapped_methods):
                                candidates = mapped_candidates
                                disposition = "consolidated-name-match"
                            elif mapped_field_candidates:
                                candidates = mapped_field_candidates
                                disposition = "value-record-field-match"
                            elif method_name == "requires":
                                disposition = "language-template-trait"
                            elif class_name in LANGUAGE_TEMPLATE_TRAIT_CLASSES:
                                disposition = "language-template-trait"
                            elif method_name == class_name or method_name == "~" + class_name:
                                disposition = "language-constructor-or-destructor"
                            elif method_name in RUNTIME_ONLY_METHODS or (class_name, method_name) in BINDING_RUNTIME_METHODS:
                                disposition = "gc-or-binding-runtime"
                            elif method_name.startswith("operator"):
                                disposition = "language-operator"
                            elif candidates:
                                disposition = "candidate-name-match"
                            else:
                                disposition = "unmatched"
                            absolute_start = segment_start + match.start()
                            inventory.append(
                                UpstreamMethod(
                                    source=source.relative_to(upstream_html).as_posix(),
                                    line=text.count("\n", 0, absolute_start) + 1,
                                    class_name=class_name,
                                    name=method_name,
                                    disposition=disposition,
                                    candidate_v_functions=candidates,
                                )
                            )
                    depth = 1
                elif character == "{" and depth > 0:
                    depth += 1
                elif character == "}" and depth > 0:
                    depth -= 1
                    if depth == 0:
                        segment_start = index + 1
                elif character == ";" and depth == 0:
                    segment_start = index + 1
                index += 1
    return inventory


def upstream_html_tests(ladybird: Path) -> list[str]:
    tests = ladybird / "Tests/LibWeb"
    if not tests.exists():
        return []
    result: list[str] = []
    for source in tests.rglob("*"):
        if not source.is_file() or "expected" in source.parts:
            continue
        relative = source.relative_to(tests)
        path = relative.as_posix()
        if "/HTML/" in "/" + path or "/wpt-import/html/" in "/" + path:
            result.append(path)
    return sorted(result)


def translated_tests(translation: Path) -> tuple[list[str], int]:
    files = sorted(path.relative_to(translation).as_posix() for path in (translation / "html").glob("*_test.v"))
    functions = 0
    for relative in files:
        text = (translation / relative).read_text()
        functions += len(re.findall(r"(?m)^fn\s+test_[A-Za-z0-9_]*\s*\(", text))
    return files, functions


def main() -> int:
    args = parse_args()
    upstream_html = args.ladybird / "Libraries/LibWeb/HTML"
    if not upstream_html.is_dir():
        raise SystemExit(f"upstream HTML directory does not exist: {upstream_html}")
    functions = v_function_names(args.translation)
    fields = v_field_names(args.translation)
    inventory = method_inventory(upstream_html, functions, fields)
    inventory.extend(header_inline_inventory(upstream_html, functions, fields))
    inventory.extend(free_function_inventory(upstream_html, functions))
    inventory.extend(qualified_header_template_inventory(upstream_html))
    inventory.sort(key=lambda method: (method.source, method.line, method.class_name, method.name))
    upstream_tests = upstream_html_tests(args.ladybird)
    v_test_files, v_test_functions = translated_tests(args.translation)
    dispositions = collections.Counter(method.disposition for method in inventory)
    unmatched_by_class = collections.Counter(
        method.class_name for method in inventory if method.disposition == "unmatched"
    )
    payload = {
        "upstream_cpp_files": len(list(upstream_html.rglob("*.cpp"))),
        "upstream_methods": len(inventory),
        "upstream_functions": len(inventory),
        "v_function_names": len(functions),
        "dispositions": dict(sorted(dispositions.items())),
        "unmatched_by_class": dict(unmatched_by_class.most_common()),
        "upstream_html_test_inputs": upstream_tests,
        "v_html_test_files": v_test_files,
        "v_html_test_functions": v_test_functions,
        "methods": [asdict(method) for method in inventory],
    }
    if args.json:
        print(json.dumps(payload, indent=2))
        return 0

    print(f"upstream .cpp files: {payload['upstream_cpp_files']}")
    print(f"upstream methods: {payload['upstream_methods']}")
    for disposition, count in dispositions.most_common():
        print(f"  {disposition}: {count}")
    print(f"upstream HTML test inputs: {len(upstream_tests)}")
    print(f"V HTML test files/functions: {len(v_test_files)}/{v_test_functions}")
    print("unmatched methods by class:")
    for class_name, count in unmatched_by_class.most_common():
        print(f"  {count:4} {class_name}")
    return 1 if dispositions["unmatched"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
