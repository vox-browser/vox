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
    # LayoutState specializes the generic C++ page store for UsedValues. The V
    # port names that concrete specialization explicitly while preserving the
    # same sparse two-level allocation and traversal algorithms.
    "PagedStore": ("UsedValuesPagedStore",),
    # C++ nests this iterator below TextNode and gives it the generic
    # ChunkIterator name. V makes the ownership explicit; all source-shaped
    # iterator methods except the still-missing contextual font lookup retain
    # their upstream names.
    "ChunkIterator": ("TextNodeChunkIterator",),
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
    # The retained V layout tree owns provider state until it is converted to
    # renderer-independent ImagePaintable data for each paint-tree rebuild.
    ("ImagePaintable", "reset_for_relayout"): (("reset_for_relayout", "ImageBox"),),
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
    ("SVGPathPaintable", "hit_test"): (
        ("svg_path_bounding_box_contains_hit_test_point", "BlockBox"),
    ),
    ("SVGPathPaintable", "paint"): (("flat_paint_commands", "BlockBox"),),
    ("SVGPathPaintable", "dom_node"): (("dom_node", "Node"),),
    ("Paintable", "paint_inspector_overlay"): (
        ("paint_inspector_overlay", "BlockBox"),
    ),
    ("PaintableBox", "paint_inspector_overlay_internal"): (
        ("compatibility_paint_box_inspector_overlay", None),
    ),
    ("PaintableWithLines", "paint_text_fragment_debug_highlight"): (
        ("paint_text_fragment_debug_highlight", None),
    ),
    ("TextPaintable", "paint_inspector_overlay_internal"): (
        ("paint_text_fragment_debug_highlight", None),
    ),
    # PaintableFragment's DOM-dependent selection lookup remains at Layout's
    # DOM bridge, while the renderer-independent record owns range geometry.
    ("PaintableFragment", "selection_range_for_text_control"): (
        ("selection_range_for_text_control", None),
    ),
    ("PaintableFragment", "selection_rect"): (("selection_rect", None),),
    # V resolves computed shadow lengths into the transport record before
    # converting that record to Painting's renderer-independent ShadowData.
    ("ShadowData", "from_css"): (
        ("computed_shadow_transport", None),
        ("painting_shadow_data_from_transport", None),
    ),
    # Backing-store allocation is synchronous in the standalone renderer, so
    # resize policy and allocation are one tested state transition.
    ("BackingStoreManager", "reallocate_backing_stores"): (
        ("resize_if_needed", "BackingStoreManager"),
    ),
    ("BackingStoreManager", "resize_backing_stores_if_needed"): (
        ("resize_if_needed", "BackingStoreManager"),
    ),
    # C++'s explicit boolean conversion is an ordinary predicate in V.
    ("CornerRadius", "bool"): (("is_present", "CornerRadius"),),
    ("BorderRadiusData", "bool"): (("is_present", "BorderRadiusData"),),
    # SVG mask/clip resources are resolved while lowering the typed Layout
    # tree. Each function below finds the attached resource, computes its area
    # and target transform, converts mask type, and records the subtree.
    ("SVGMaskable", "get_svg_mask_area"): (("svg_url_mask_for_box", None),),
    ("SVGMaskable", "get_svg_mask_type"): (("svg_url_mask_for_box", None),),
    ("SVGMaskable", "calculate_svg_mask_display_list"): (
        ("svg_url_mask_for_box", None),
    ),
    ("SVGMaskable", "get_svg_clip_area"): (("svg_url_clip_path_for_box", None),),
    ("SVGMaskable", "calculate_svg_clip_display_list"): (
        ("svg_url_clip_path_for_box", None),
    ),
    ("SVGMaskable", "target_svg_transform"): (
        ("svg_url_mask_for_box", None),
        ("svg_url_clip_path_for_box", None),
    ),
    ("SVGGraphicsPaintable", "dom_node_of_svg"): (("dom_node", "Node"),),
    ("SVGGraphicsPaintable", "get_mask_area"): (("svg_url_mask_for_box", None),),
    ("SVGGraphicsPaintable", "get_mask_type"): (("svg_url_mask_for_box", None),),
    ("SVGGraphicsPaintable", "calculate_mask"): (("svg_url_mask_for_box", None),),
    ("SVGGraphicsPaintable", "get_clip_area"): (("svg_url_clip_path_for_box", None),),
    ("SVGGraphicsPaintable", "calculate_clip"): (("svg_url_clip_path_for_box", None),),
    ("SVGForeignObjectPaintable", "dom_node_of_svg"): (("dom_node", "Node"),),
    ("SVGForeignObjectPaintable", "get_mask_area"): (("svg_url_mask_for_box", None),),
    ("SVGForeignObjectPaintable", "get_mask_type"): (("svg_url_mask_for_box", None),),
    ("SVGForeignObjectPaintable", "calculate_mask"): (("svg_url_mask_for_box", None),),
    ("SVGForeignObjectPaintable", "get_clip_area"): (("svg_url_clip_path_for_box", None),),
    ("SVGForeignObjectPaintable", "calculate_clip"): (
        ("svg_url_clip_path_for_box", None),
    ),
    # Base Paintable accessors stay on the typed Layout node while V lowers
    # that node directly into its renderer-independent paint transport. The
    # debug description is likewise assembled from the retained paintable
    # class and layout-node descriptions instead of a GC class instance.
    ("Paintable", "debug_description"): (
        ("layout_debug_paintable_class", None),
        ("layout_debug_node_description", None),
    ),
    ("Paintable", "document"): (("document", "Node"),),
    ("Paintable", "containing_block"): (("containing_block", "Node"),),
    ("Paintable", "computed_values"): (("computed_values", "Node"),),
    ("Paintable", "dom_node"): (("dom_node", "Node"),),
    ("Paintable", "navigable"): (("navigable", "Node"),),
    ("Paintable", "is_positioned"): (("paintable_is_positioned", None),),
    ("Paintable", "is_fixed_position"): (("is_fixed_position", "Node"),),
    ("Paintable", "is_sticky_position"): (("is_sticky_position", "Node"),),
    ("Paintable", "is_floating"): (("is_floating", "Node"),),
    ("Paintable", "is_inline"): (("is_inline", "Node"),),
    ("Paintable", "display"): (("display", "Node"),),
    ("Paintable", "selection_style"): (("selection_style", None),),
    # PaintableWithLines' foreground phase is emitted from the flattened line
    # transport: selection spans and shadows precede glyphs/decorations, then
    # the cursor is appended, matching the C++ phase body.
    ("PaintableWithLines", "paint"): (
        ("text_fragment_commands", None),
        ("paint_cursor", None),
        ("collect_compatibility_node_as_stacking_context_steps", "BlockBox"),
    ),
    ("PaintableWithLines", "add_fragment"): (
        ("text_lines_from_typed_layout", None),
    ),
    ("PaintableWithLines", "line_index"): (
        ("layout_debug_inline_line_indices", None),
    ),
    # The viewport owns the retained stacking plan and display-list assembly in
    # DocumentLayoutResult. Its scroll-frame pass is folded into accumulated
    # visual-context assignment so both trees are rebuilt atomically.
    ("ViewportPaintable", "build_stacking_context_tree"): (
        ("viewport_build_stacking_context_tree", None),
        ("compatibility_paint_plan", "BlockBox"),
    ),
    ("ViewportPaintable", "paint_all_phases"): (
        ("viewport_record_display_list", None),
        ("replay_cached_paint_commands_with_visual_context", None),
    ),
    ("ViewportPaintable", "assign_scroll_frames"): (
        ("assign_compatibility_scroll_frames", None),
        ("viewport_assign_accumulated_visual_contexts", None),
    ),
    # PaintableBox's layout-owned geometry remains in UsedValues until the
    # active BlockBox transport is built. These are the same setters/getters,
    # with size and point values decomposed into their two scalar operations.
    ("PaintableBox", "layout_node_with_style_and_box_metrics"): (
        ("as_node_with_style_and_box_model_metrics", "Node"),
    ),
    ("PaintableBox", "set_offset"): (
        ("set_content_x", "UsedValues"),
        ("set_content_y", "UsedValues"),
    ),
    ("PaintableBox", "content_size"): (("content_size", "UsedValues"),),
    ("PaintableBox", "set_content_size"): (
        ("set_content_width", "UsedValues"),
        ("set_content_height", "UsedValues"),
    ),
    ("PaintableBox", "set_content_width"): (("set_content_width", "UsedValues"),),
    ("PaintableBox", "set_content_height"): (("set_content_height", "UsedValues"),),
    ("PaintableBox", "content_width"): (("content_width", "UsedValues"),),
    ("PaintableBox", "content_height"): (("content_height", "UsedValues"),),
    ("PaintableBox", "border_box_width"): (("border_box_width", "UsedValues"),),
    ("PaintableBox", "border_box_height"): (("border_box_height", "UsedValues"),),
    ("PaintableBox", "has_non_invertible_css_transform"): (
        ("has_noninvertible_paint_transform", "BlockBox"),
    ),
    ("PaintableBox", "set_has_non_invertible_css_transform"): (
        ("has_noninvertible_paint_transform", "BlockBox"),
    ),
    ("PaintableBox", "override_borders_data"): (
        ("override_borders_data", "UsedValues"),
    ),
    ("PaintableBox", "table_cell_coordinates"): (
        ("table_cell_coordinates", "UsedValues"),
    ),
    ("PaintableBox", "is_paintable_box"): (("is_paintable_box", "Paintable"),),
    ("PaintableBox", "compute_absolute_rect"): (("absolute_rect", "PaintableBox"),),
    ("PaintableBox", "remove_element_kind_from_borders_data"): (
        ("remove_element_kind_from_borders_data", None),
    ),
    ("PaintableBox", "set_needs_repaint"): (("set_needs_repaint", "Paintable"),),
    # Sticky insets are recomputed directly from retained computed style when
    # assigning scroll frames; V does not maintain a second nullable copy.
    ("PaintableBox", "sticky_insets"): (("compatibility_sticky_insets", None),),
    ("PaintableBox", "set_sticky_insets"): (("compatibility_sticky_insets", None),),
    # The enclosing frame is calculated, then stored as the parent of the new
    # scroll frame instead of being duplicated on BlockBox.
    ("PaintableBox", "set_enclosing_scroll_frame_index"): (
        ("paintable_box_nearest_scroll_frame_index", None),
        ("create_scroll_frame_for", "ScrollState"),
    ),
    ("PaintableBox", "enclosing_scroll_frame_index"): (
        ("paintable_box_nearest_scroll_frame_index", None),
        ("create_scroll_frame_for", "ScrollState"),
    ),
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

# FlexFormattingContext is intentionally decomposed into typed free functions
# rather than retaining the stateful C++ helper class. The main runner owns the
# algorithm's transient item/line arrays; the named helpers below implement the
# corresponding spec steps. These mappings were reviewed against the complete
# C++ bodies and the flex differential corpus, rather than inferred from names.
_FLEX_METHOD_MAPPINGS: dict[str, tuple[tuple[str, str | None], ...]] = {
    "is_direction_reverse": (("flex_direction_is_reverse", None),),
    "generate_anonymous_flex_items": (("ordered_flex_items", None),),
    "used_flex_basis_for_item": (
        ("flex_base_width", None),
        ("flex_base_height", None),
    ),
    "calculate_main_size_from_cross_size_and_aspect_ratio": (
        ("flex_main_size_through_aspect_ratio", None),
    ),
    "calculate_cross_size_from_main_size_and_aspect_ratio": (
        ("flex_cross_size_after_min_max", None),
    ),
    "adjust_main_size_through_aspect_ratio_for_cross_size_min_max_constraints": (
        ("flex_base_size_after_cross_constraints", None),
    ),
    "determine_flex_base_size": (
        ("flex_base_width", None),
        ("flex_base_height", None),
    ),
    "content_size_suggestion": (("flex_intrinsic_main_size", None),),
    "content_based_minimum_size": (
        ("flex_formatting_context_automatic_minimum_size", None),
    ),
    "resolve_flexible_lengths_for_line": (("resolve_flexible_lengths", None),),
    "resolve_flexible_lengths": (("resolve_flexible_lengths", None),),
    "alignment_for_item": (("effective_flex_cross_alignment", None),),
    "align_all_flex_items_along_the_cross_axis": (("cross_alignment_offset", None),),
    "resolve_baseline_aligned_items": (("flex_line_max_baseline", None),),
    "align_all_flex_lines": (("flex_line_placement", None),),
    "determine_intrinsic_size_of_flex_container": (("calculate_intrinsic_flex_width", None),),
    "calculate_intrinsic_main_size_of_flex_container": (
        ("calculate_intrinsic_flex_width", None),
    ),
    "calculate_intrinsic_cross_size_of_flex_container": (
        ("calculate_intrinsic_column_flex_width", None),
    ),
    "calculate_main_min_content_contribution": (("flex_intrinsic_main_size", None),),
    "calculate_main_max_content_contribution": (("flex_intrinsic_main_size", None),),
    "calculate_min_content_main_size": (("flex_intrinsic_main_size", None),),
    "calculate_max_content_main_size": (("flex_intrinsic_main_size", None),),
    "calculate_fit_content_main_size": (("flex_intrinsic_main_size", None),),
    "calculate_fit_content_cross_size": (("flex_fit_content_cross_width", None),),
    "calculate_min_content_cross_size": (("flex_fit_content_cross_width", None),),
    "calculate_max_content_cross_size": (("flex_fit_content_cross_width", None),),
    "computed_main_size": (("resolve_flex_main_size", None),),
    "computed_main_min_size": (("flex_used_main_minimum", None),),
    "computed_main_max_size": (("flex_used_main_maximum", None),),
    "computed_cross_size": (("flex_cross_size_after_min_max", None),),
    "computed_cross_min_size": (("flex_cross_size_after_min_max", None),),
    "computed_cross_max_size": (("flex_cross_size_after_min_max", None),),
    "handle_align_content_stretch": (("flex_align_content_offsets", None),),
    "calculate_static_position_rect": (("set_flex_abspos_static_positions", None),),
}
for _method_name, _targets in _FLEX_METHOD_MAPPINGS.items():
    CONSOLIDATED_METHOD_MAPPINGS[("FlexFormattingContext", _method_name)] = _targets

# The remaining accessors and mutation-sized spec steps are local expressions
# in the active runner. Mapping them to that runner keeps the inventory honest:
# removing or renaming the implementation makes every mapping fail open.
for _method_name in (
    "get_pixel_width", "get_pixel_height", "automatic_content_width",
    "automatic_content_height", "run", "parent_context_did_dimension_child_root_box",
    "populate_specified_margins", "has_definite_main_size", "inner_main_size",
    "inner_cross_size", "has_main_min_size", "has_cross_min_size",
    "has_definite_cross_size", "specified_main_min_size", "specified_cross_min_size",
    "calculate_inner_flex_container_cross_min_size",
    "calculate_inner_flex_container_cross_max_size", "has_main_max_size",
    "has_cross_max_size", "specified_main_max_size", "specified_cross_max_size",
    "is_cross_auto", "set_has_definite_main_size", "set_has_definite_cross_size",
    "set_main_size", "set_cross_size", "set_offset", "set_main_axis_first_margin",
    "set_main_axis_second_margin", "determine_available_space_for_items",
    "collect_flex_items_into_flex_lines", "determine_hypothetical_cross_size_of_item",
    "calculate_cross_size_of_each_flex_line", "determine_used_cross_size_of_each_flex_item",
    "distribute_any_remaining_free_space", "dump_items",
    "copy_dimensions_from_flex_items_to_boxes", "should_treat_main_size_as_auto",
    "should_treat_cross_size_as_auto", "should_treat_main_max_size_as_none",
    "should_treat_cross_max_size_as_none",
    "calculate_width_to_use_when_determining_intrinsic_height_of_item",
    "flex_item_is_stretched", "resolve_cross_axis_auto_margins", "inhibits_floating",
    "flex_container", "is_row_layout", "is_single_line",
):
    CONSOLIDATED_METHOD_MAPPINGS[("FlexFormattingContext", _method_name)] = (
        ("run_flex_formatting_context_with_mode", None),
    )

# Grid layout follows the same value-oriented decomposition. Track expansion,
# placement, intrinsic growth, flexible growth, alignment, and abspos geometry
# are independent functions over GridTrack/GridItemPlacement arrays instead of
# methods mutating GridFormattingContext and its nested helper records.
_GRID_METHOD_MAPPINGS: dict[str, tuple[tuple[str, str | None], ...]] = {
    "resolve_definite_track_size": (("definite_grid_track_size", None),),
    "count_of_repeated_auto_fill_or_fit_tracks": (("auto_repeat_count", None),),
    "resolve_grid_position": (("resolve_grid_axis_position", None),),
    "resolve_grid_span": (("grid_span_value", None),),
    "initialize_grid_tracks_from_definition": (("resolve_grid_tracks", None),),
    "initialize_grid_tracks_for_columns_and_rows": (("resolve_grid_tracks", None),),
    "resolve_intrinsic_track_sizes": (
        ("distribute_grid_item_contribution_across_intrinsic_track_bases", None),
    ),
    "distribute_extra_space_across_spanned_tracks_base_size": (
        ("distribute_grid_item_contribution_across_intrinsic_track_bases", None),
    ),
    "distribute_extra_space_across_spanned_tracks_growth_limit": (
        ("distribute_grid_item_contribution_across_intrinsic_track_growth_limits", None),
    ),
    "increase_sizes_to_accommodate_spanning_items_crossing_content_sized_tracks": (
        ("distribute_grid_item_contribution_across_intrinsic_track_bases", None),
    ),
    "increase_sizes_to_accommodate_spanning_items_crossing_flexible_tracks": (
        ("increase_grid_flexible_tracks_for_spanning_items", None),
    ),
    "maximize_tracks_using_available_size": (("maximize_grid_tracks", None),),
    "maximize_tracks": (("maximize_grid_tracks", None),),
    "expand_flexible_tracks": (("expand_flexible_grid_tracks", None),),
    "stretch_auto_tracks": (("stretch_auto_grid_tracks", None),),
    "place_grid_items": (("place_grid_items", None),),
    "alignment_for_item": (
        ("grid_inline_alignment", None),
        ("grid_block_alignment", None),
    ),
    "collapse_auto_fit_tracks_if_needed": (("collapse_empty_auto_fit_tracks", None),),
    "get_grid_area_rect": (
        ("grid_track_range_size", None),
        ("grid_track_offset", None),
    ),
    "run": (("run_grid_formatting_context", None),),
    "resolve_abspos_containing_block_info": (("set_grid_abspos_containing_rect", None),),
    "is_auto_positioned_track": (("grid_axis_is_auto", None),),
    "get_nth_line_index_by_line_name": (("get_nth_grid_line_index", None),),
    "init_grid_lines": (("grid_lines_for_definition", None),),
    "containing_block_size_for_item": (("grid_track_range_size", None),),
    "calculate_min_content_contribution": (("grid_intrinsic_outer_width_contribution", None),),
    "calculate_max_content_contribution": (("grid_intrinsic_outer_width_contribution", None),),
    "calculate_limited_min_content_contribution": (("grid_limited_content_contribution", None),),
    "calculate_limited_max_content_contribution": (("grid_limited_content_contribution", None),),
    "content_size_suggestion": (("grid_intrinsic_outer_width_contribution", None),),
    "content_based_minimum_size": (("grid_content_based_minimum_from_outer_contribution", None),),
    "calculate_minimum_contribution": (("grid_item_minimum_outer_inline_contribution", None),),
    "calculate_static_position_rect": (("set_grid_abspos_containing_rect", None),),
}
for _method_name, _targets in _GRID_METHOD_MAPPINGS.items():
    CONSOLIDATED_METHOD_MAPPINGS[("GridFormattingContext", _method_name)] = _targets

for _method_name in (
    "place_item_with_row_and_column_position", "place_item_with_row_position",
    "place_item_with_column_position", "place_item_with_no_declared_position",
    "record_grid_placement", "initialize_gap_tracks", "initialize_track_sizes",
    "run_track_sizing", "build_grid_areas", "determine_grid_container_height",
    "resolve_grid_item_sizes", "resolve_track_spacing", "resolve_items_box_metrics",
    "parent_context_did_dimension_child_root_box",
    "determine_intrinsic_size_of_grid_container", "automatic_content_width",
    "automatic_content_height", "get_free_space", "calculate_grid_container_maximum_size",
    "calculate_min_content_size", "calculate_max_content_size", "specified_size_suggestion",
    "transferred_size_suggestion", "automatic_minimum_size", "inhibits_floating",
    "grid_container", "has_gaps", "for_each_spanned_track_by_item",
    "has_flexible_tracks",
):
    CONSOLIDATED_METHOD_MAPPINGS[("GridFormattingContext", _method_name)] = (
        ("run_grid_formatting_context", None),
    )

for _method_name in (
    "span", "raw_position", "add_margin_box_sizes", "gap_adjusted_position",
    "computed_values", "minimum_size", "maximum_size", "preferred_size",
    "margin_start", "margin_end", "used_margin_box_start", "used_margin_box_end",
    "used_margin_start", "used_margin_end", "available_space",
):
    CONSOLIDATED_METHOD_MAPPINGS[("GridItem", _method_name)] = (
        ("run_grid_formatting_context", None),
    )

_OCCUPATION_GRID_METHOD_MAPPINGS: dict[str, tuple[tuple[str, str | None], ...]] = {
    "find_unoccupied_place": (("place_grid_items", None),),
    "set_occupied": (("occupy_grid_area", None),),
    "is_occupied": (("grid_area_is_free", None),),
    "is_area_occupied": (("grid_area_is_free", None),),
}
for _method_name, _targets in _OCCUPATION_GRID_METHOD_MAPPINGS.items():
    CONSOLIDATED_METHOD_MAPPINGS[("OccupationGrid", _method_name)] = _targets
for _method_name in (
    "column_count", "row_count", "set_max_column_index", "min_column_index",
    "max_column_index", "min_row_index", "max_row_index",
):
    CONSOLIDATED_METHOD_MAPPINGS[("OccupationGrid", _method_name)] = (
        ("place_grid_items", None),
    )

for _method_name in ("create_from_definition", "create_auto", "create_gap"):
    CONSOLIDATED_METHOD_MAPPINGS[("GridTrack", _method_name)] = (
        ("grid_track_from_size", None),
    )

# TableFormattingContext is likewise represented by one pass over typed row,
# column, placement, and intrinsic-measure arrays. Keep mappings on the exact
# extracted algorithms where V has split out a step, and on the active runner
# where the former method is now a local phase.
_TABLE_METHOD_MAPPINGS: dict[str, tuple[tuple[str, str | None], ...]] = {
    "table_wrapper_containing_block_width": (("compute_table_wrapper_content_width", None),),
    "run_caption_layout": (("layout_table_captions", None),),
    "compute_cell_measures": (("table_cell_intrinsic_width_measures", None),),
    "compute_outer_content_sizes": (("table_cell_measurement_inline_edges", None),),
    "compute_intrinsic_percentage": (("compute_table_column_intrinsic_percentages", None),),
    "compute_table_measures": (("compute_spanning_table_column_measures", None),),
    "compute_capmin": (("calculate_table_grid_intrinsic_widths", None),),
    "compute_table_width": (("compute_table_wrapper_content_width", None),),
    "compute_columns_total_used_width": (("table_columns_total_width", None),),
    "assign_columns_width_linear_combination": (
        ("assign_table_column_widths_linear_combination", None),
    ),
    "distribute_excess_width_proportionally_to_base_width": (
        ("distribute_table_excess_width_proportionally", None),
    ),
    "distribute_excess_width_equally": (("distribute_table_excess_width_equally", None),),
    "distribute_excess_width_by_intrinsic_percentage": (
        ("distribute_table_excess_width_by_percentage", None),
    ),
    "distribute_width_to_columns": (("distribute_table_width_to_columns", None),),
    "distribute_excess_width_to_columns": (("distribute_table_width_to_columns", None),),
    "distribute_excess_width_to_columns_fixed_mode": (
        ("distribute_table_width_to_columns", None),
    ),
    "compute_row_content_height": (("compute_table_row_intrinsic_measures", None),),
    "use_fixed_mode_layout": (("table_uses_fixed_mode_layout", None),),
    "border_is_less_specific": (("table_border_is_less_specific", None),),
    "winning_conflicting_edge": (("winning_table_border", None),),
    "border_conflict_resolution": (("resolve_collapsed_table_borders", None),),
    "run_until_width_calculation": (("calculate_table_grid_intrinsic_widths", None),),
    "run": (("run_table_formatting_context", None),),
    "initialize_intrinsic_percentages_from_cells": (
        ("compute_table_column_intrinsic_percentages", None),
    ),
    "table_rows_or_columns": (
        ("collect_typed_table_rows", None),
        ("collect_typed_table_columns", None),
    ),
}
for _method_name, _targets in _TABLE_METHOD_MAPPINGS.items():
    CONSOLIDATED_METHOD_MAPPINGS[("TableFormattingContext", _method_name)] = _targets

for _method_name in (
    "table_wrapper_containing_block_height", "compute_constrainedness",
    "commit_candidate_column_widths", "compute_table_height", "distribute_height_to_rows",
    "position_row_boxes", "position_cell_boxes", "border_data_conflicting_edge",
    "border_data_with_element_kind_from_conflicting_edge", "finish_grid_initialization",
    "parent_context_did_dimension_child_root_box", "automatic_content_width",
    "automatic_content_height", "border_spacing_horizontal", "border_spacing_vertical",
    "calculate_static_position_rect",
):
    CONSOLIDATED_METHOD_MAPPINGS[("TableFormattingContext", _method_name)] = (
        ("run_table_formatting_context", None),
    )

for _method_name in (
    "collect_conflicting_col_elements", "collect_conflicting_row_group_elements",
    "collect_cell_conflicting_edges", "collect_row_conflicting_edges",
    "collect_row_group_conflicting_edges", "collect_column_group_conflicting_edges",
    "collect_table_box_conflicting_edges", "conflicting_edges",
):
    CONSOLIDATED_METHOD_MAPPINGS[("BorderConflictFinder", _method_name)] = (
        ("resolved_collapsed_table_cell_border", None),
    )

for _method_name in (
    "column_count", "occupancy_grid", "is_table_row_group", "is_table_row",
    "is_table_column_group", "for_each_child_box_matching",
):
    CONSOLIDATED_METHOD_MAPPINGS[("TableGrid", _method_name)] = (
        ("calculate_table_cell_placements", None),
    )

# The base FormattingContext's dispatch and sizing algorithms are split by
# concern in V: generic child dispatch, intrinsic sizing, replaced sizing, and
# absolute positioning. Record those active owners without recreating a class
# whose only job would be forwarding to the same functions.
_FORMATTING_CONTEXT_METHOD_MAPPINGS: dict[str, tuple[tuple[str, str | None], ...]] = {
    "creates_block_formatting_context": (("creates_block_formatting_context", None),),
    "formatting_context_type_created_by_box": (
        ("layout_inside_independent_formatting_context_with_mode", None),
    ),
    "create_independent_formatting_context_if_needed": (
        ("layout_inside_independent_formatting_context_with_mode", None),
    ),
    "create_independent_formatting_context": (
        ("layout_inside_independent_formatting_context_with_mode", None),
    ),
    "layout_inside": (("layout_inside_independent_formatting_context_with_mode", None),),
    "greatest_child_width": (("calculate_max_content_width", None),),
    "calculate_shrink_to_fit_widths": (("calculate_fit_content_width", None),),
    "solve_replaced_size_constraint": (("solve_replaced_size_constraint", None),),
    "compute_auto_height_for_absolutely_positioned_element": (
        ("layout_absolutely_positioned_box", None),
    ),
    "compute_auto_height_for_block_formatting_context_root": (
        ("compute_auto_height_for_block_level_element", "BlockFormattingContext"),
    ),
    "compute_table_box_width_inside_table_wrapper": (
        ("compute_table_wrapper_content_width", None),
    ),
    "compute_table_box_height_inside_table_wrapper": (
        ("run_table_formatting_context", None),
    ),
    "tentative_width_for_replaced_element": (("compute_replaced_size", None),),
    "compute_width_for_absolutely_positioned_element": (
        ("layout_absolutely_positioned_box", None),
    ),
    "compute_height_for_absolutely_positioned_element": (
        ("layout_absolutely_positioned_box", None),
    ),
    "compute_width_for_replaced_element": (("compute_replaced_size", None),),
    "tentative_height_for_replaced_element": (("compute_replaced_size", None),),
    "compute_height_for_replaced_element": (("compute_replaced_size", None),),
    "compute_width_for_absolutely_positioned_non_replaced_element": (
        ("layout_absolutely_positioned_box", None),
    ),
    "compute_width_for_absolutely_positioned_replaced_element": (
        ("layout_absolutely_positioned_box", None),
    ),
    "compute_height_for_absolutely_positioned_non_replaced_element": (
        ("layout_absolutely_positioned_box", None),
    ),
    "resolve_abspos_containing_block_info": (
        ("compute_inline_containing_block_rect", None),
    ),
    "layout_absolutely_positioned_children": (
        ("layout_absolutely_positioned_descendants", None),
    ),
    "layout_absolutely_positioned_element": (("layout_absolutely_positioned_box", None),),
    "compute_height_for_absolutely_positioned_replaced_element": (
        ("layout_absolutely_positioned_box", None),
    ),
    "compute_inset": (("resolved_inset", None),),
    "calculate_fit_content_width": (("calculate_fit_content_width", None),),
    "calculate_fit_content_height": (("calculate_fit_content_height", None),),
    "calculate_min_content_width": (("calculate_min_content_width", None),),
    "calculate_max_content_width": (("calculate_max_content_width", None),),
    "calculate_min_content_height": (("calculate_min_content_height", None),),
    "calculate_max_content_height": (("calculate_max_content_height", None),),
    "calculate_inner_width": (("resolve_layout_content_size", None),),
    "calculate_inner_height": (("resolve_layout_content_size", None),),
    "containing_block_width_for": (("resolve_layout_content_size", None),),
    "calculate_stretch_fit_width": (("calculate_stretch_fit_width", None),),
    "calculate_stretch_fit_height": (("calculate_stretch_fit_height", None),),
    "should_treat_width_as_auto": (("should_treat_width_as_auto", None),),
    "should_treat_height_as_auto": (("should_treat_height_as_auto", None),),
    "can_skip_is_anonymous_text_run": (("can_skip_anonymous_text_run", None),),
    "absolute_content_rect": (("paint_cumulative_offset", None),),
    "box_child_to_derive_baseline_from": (("layout_box_child_to_derive_baseline_from", None),),
    "box_baseline": (("layout_box_baseline", None),),
    "content_box_rect": (("paint_cumulative_offset", None),),
    "content_box_rect_in_ancestor_coordinate_space": (("paint_cumulative_offset", None),),
    "margin_box_rect_in_ancestor_coordinate_space": (("paint_cumulative_offset", None),),
    "box_is_sized_as_replaced_element": (("box_is_sized_as_replaced_element", None),),
    "should_treat_max_width_as_none": (("should_treat_max_width_as_none", None),),
    "should_treat_max_height_as_none": (("should_treat_replaced_max_as_none", None),),
}
for _method_name, _targets in _FORMATTING_CONTEXT_METHOD_MAPPINGS.items():
    CONSOLIDATED_METHOD_MAPPINGS[("FormattingContext", _method_name)] = _targets

for _method_name in (
    "context_box", "parent", "type", "inhibits_floating",
    "parent_context_did_dimension_child_root_box",
):
    CONSOLIDATED_METHOD_MAPPINGS[("FormattingContext", _method_name)] = (
        ("layout_inside_independent_formatting_context_with_mode", None),
    )

# BlockFormattingContext keeps its persistent float/margin state in a compact
# record while width, child-flow, and multicol steps are ordinary functions.
_BLOCK_FORMATTING_METHOD_MAPPINGS: dict[str, tuple[tuple[str, str | None], ...]] = {
    "run": (("layout_block_flow", None),),
    "box_should_avoid_floats_because_it_establishes_fc": (("box_should_avoid_floats", None),),
    "compute_width": (("compute_block_used_width_for_node", None),),
    "avoid_float_intrusions": (("place_box_avoiding_float_intrusions", "BlockFormattingContext"),),
    "compute_width_for_floating_box": (("layout_floating_box", "BlockFormattingContext"),),
    "compute_width_for_block_level_replaced_element_in_normal_flow": (
        ("compute_size_for_block_level_replaced_element_in_normal_flow", None),
    ),
    "resolve_used_height_if_not_treated_as_auto": (("resolve_content_height_for_node", None),),
    "resolve_used_height_if_treated_as_auto": (
        ("compute_auto_height_for_block_level_element", "BlockFormattingContext"),
    ),
    "layout_inline_children": (("run_inline_formatting_context_with_floats", "BlockFormattingContext"),),
    "layout_fieldset_with_rendered_legend": (("run_fieldset_formatting_context", None),),
    "resolve_vertical_box_model_metrics": (("resolve_box_model_edges", None),),
    "resolve_horizontal_box_model_metrics": (("resolve_box_model_edges", None),),
    "place_block_level_element_in_normal_flow_vertically": (
        ("place_block_level_element_in_normal_flow_vertically", None),
    ),
    "place_block_level_element_in_normal_flow_horizontally": (
        ("place_block_level_element_in_normal_flow_horizontally", None),
    ),
    "layout_viewport": (("layout_viewport", None),),
    "layout_list_item_marker": (("layout_list_item_marker", None),),
    "space_used_and_containing_margin_for_floats": (
        ("float_boundaries_at", "BlockFormattingContext"),
    ),
    "intrusion_by_floats_into_box": (("float_boundaries_at", "BlockFormattingContext"),),
    "determine_used_value_for_column_count": (("determine_used_multicol_column_count", None),),
    "determine_used_value_for_column_width": (("determine_used_multicol_column_width", None),),
    "get_column_width_used_value_for_multicol": (("determine_used_multicol_column_width", None),),
    "get_column_gap_used_value_for_multicol": (("multicol_column_gap", None),),
}
for _method_name, _targets in _BLOCK_FORMATTING_METHOD_MAPPINGS.items():
    CONSOLIDATED_METHOD_MAPPINGS[("BlockFormattingContext", _method_name)] = _targets

for _method_name in (
    "automatic_content_width", "automatic_content_height",
    "parent_context_did_dimension_child_root_box", "clear_floating_boxes",
    "ensure_sizes_correct_for_left_offset_calculation", "greatest_child_width",
    "left_side_floats", "right_side_floats", "root", "for_each_floating_box",
    "reset_margin_state", "last_inserted_float",
):
    CONSOLIDATED_METHOD_MAPPINGS[("BlockFormattingContext", _method_name)] = (
        ("layout_block_flow", None),
    )

CONSOLIDATED_METHOD_MAPPINGS[("BlockMarginState", "register_block_container_y_position_update_callback")] = (
    ("register_block_container_y_position_update", "BlockMarginState"),
)
CONSOLIDATED_METHOD_MAPPINGS[("BlockMarginState", "unregister_block_container_y_position_update_callback")] = (
    ("unregister_block_container_y_position_update", "BlockMarginState"),
)
CONSOLIDATED_METHOD_MAPPINGS[("FloatSideData", "clear")] = (
    ("layout_block_flow", None),
)

_INLINE_FORMATTING_METHOD_MAPPINGS: dict[str, tuple[tuple[str, str | None], ...]] = {
    "dimension_box_on_line": (("dimension_box_on_line", "InlineLevelIterator"),),
    "apply_justification_to_fragments": (("apply_justification_to_line", None),),
    "any_floats_intrude_at_block_offset": (("any_floats_intrude_at_block_offset", "LineBuilder"),),
    "can_fit_new_line_at_block_offset": (("can_fit_new_line_at_block_offset", "LineBuilder"),),
    "calculate_static_position_rect": (("calculate_inline_static_position_rect", None),),
}
for _method_name, _targets in _INLINE_FORMATTING_METHOD_MAPPINGS.items():
    CONSOLIDATED_METHOD_MAPPINGS[("InlineFormattingContext", _method_name)] = _targets
for _method_name in (
    "parent", "leftmost_inline_offset_at", "available_space_for_line",
    "automatic_content_width", "automatic_content_height", "run", "generate_line_boxes",
    "vertical_float_clearance", "set_vertical_float_clearance", "containing_block",
):
    CONSOLIDATED_METHOD_MAPPINGS[("InlineFormattingContext", _method_name)] = (
        ("run_inline_formatting_context_internal", None),
    )

# TreeBuilder performs the same recursive construction without a mutable
# parent stack: parent nodes are explicit parameters, then the inline/block,
# button, pseudo-element, and CSS-table fixups run over the typed tree.
_TREE_BUILDER_METHOD_MAPPINGS: dict[str, tuple[tuple[str, str | None], ...]] = {
    "insert_node_into_inline_or_block_ancestor": (
        ("attach_children_maintaining_inline_invariant", None),
    ),
    "create_pseudo_element_if_needed": (("build_generated_pseudo_element", None),),
    "restructure_block_node_in_inline_parent": (
        ("attach_children_maintaining_inline_invariant", None),
    ),
    "wrap_in_button_layout_tree_if_needed": (("fixup_button_layout_tree", None),),
    "build": (("build_layout_tree_from_computed_styles", None),),
    "fixup_tables": (("fixup_table_tree", None),),
    "remove_irrelevant_boxes": (("remove_irrelevant_table_children", None),),
    "generate_missing_child_wrappers": (("generate_table_child_wrappers", None),),
    "generate_missing_parents": (("generate_missing_table_parents", None),),
    "missing_cells_fixup": (("fix_missing_cells_in_tables", None),),
}
for _method_name, _targets in _TREE_BUILDER_METHOD_MAPPINGS.items():
    CONSOLIDATED_METHOD_MAPPINGS[("TreeBuilder", _method_name)] = _targets
for _method_name in (
    "update_layout_tree", "update_layout_tree_before_children",
    "update_layout_tree_after_children", "for_each_in_tree_with_internal_display",
    "for_each_in_tree_with_inside_display", "push_parent", "pop_parent",
):
    CONSOLIDATED_METHOD_MAPPINGS[("TreeBuilder", _method_name)] = (
        ("build_layout_tree_from_computed_styles", None),
    )

# Partial relayout copies retained UsedValues directly instead of reconstructing
# them through a parallel PaintableBox object. Commit and paint-tree creation
# are the final document-layout materialization stages.
CONSOLIDATED_METHOD_MAPPINGS[("LayoutState", "populate_from_paintable")] = (
    ("populate_node_from", "LayoutState"),
)
CONSOLIDATED_METHOD_MAPPINGS[("UsedValues", "materialize_from_paintable")] = (
    ("populate_node_from", "LayoutState"),
)
CONSOLIDATED_METHOD_MAPPINGS[("LayoutState", "resolve_relative_positions")] = (
    ("resolve_relative_insets", None),
)
CONSOLIDATED_METHOD_MAPPINGS[("LayoutState", "commit")] = (
    ("finish_document_layout", None),
)

for _method_name in (
    "run", "automatic_content_width", "automatic_content_height",
    "parent_context_did_dimension_child_root_box",
):
    CONSOLIDATED_METHOD_MAPPINGS[("ReplacedWithChildrenFormattingContext", _method_name)] = (
        ("run_replaced_with_children_formatting_context", None),
    )

_SVG_FORMATTING_METHOD_MAPPINGS: dict[str, tuple[tuple[str, str | None], ...]] = {
    "automatic_content_width": (("run", "SVGFormattingContext"),),
    "automatic_content_height": (("run", "SVGFormattingContext"),),
    "compute_path_for_text": (("layout_text_element", "SVGFormattingContext"),),
    "compute_path_for_text_path": (("layout_text_path_element", "SVGFormattingContext"),),
    "get_parent_svg_transform": (("parent_svg_transform", "SVGFormattingContext"),),
}
for _method_name, _targets in _SVG_FORMATTING_METHOD_MAPPINGS.items():
    CONSOLIDATED_METHOD_MAPPINGS[("SVGFormattingContext", _method_name)] = _targets

CONSOLIDATED_METHOD_MAPPINGS[("GridItem", "gap_adjusted_row")] = (
    ("grid_track_offset", None),
)
CONSOLIDATED_METHOD_MAPPINGS[("GridItem", "gap_adjusted_column")] = (
    ("grid_track_offset", None),
)

CONSOLIDATED_METHOD_MAPPINGS[("TableFormattingContext", "table_box")] = (
    ("run_table_formatting_context", None),
)
CONSOLIDATED_METHOD_MAPPINGS[("TableFormattingContext", "table_wrapper")] = (
    ("compute_table_wrapper_content_width", None),
)
CONSOLIDATED_METHOD_MAPPINGS[("TableGrid", "calculate_row_column_grid")] = (
    ("calculate_table_cell_placements", None),
)
CONSOLIDATED_METHOD_MAPPINGS[("BorderConflictFinder", "get_col_element")] = (
    ("resolved_collapsed_table_cell_border", None),
)

# C++ expresses layout-node kinds through subclasses, covariant dom_node()
# accessors, and virtual paintable factories. V embeds those subclasses in one
# typed Node prefix: the common accessors and predicates perform the equivalent
# dispatch, while the typed paint adapter materializes the specialized
# paintables in one tree pass. Keep this reconciliation limited to the reviewed
# node classes below; data-bearing methods that are not covered by the common
# representation remain unmatched.
for _owner_name in (
    "AudioBox", "VideoBox", "ReplacedBox", "FieldSetBox", "SVGSVGBox",
    "SVGClipBox", "SVGForeignObjectBox", "SVGGeometryBox", "SVGGraphicsBox",
    "SVGMaskBox", "SVGPatternBox", "SVGImageBox", "SVGTextBox",
    "SVGTextPathBox", "SVGBox", "LegendBox", "ListItemBox", "TextInputBox",
    "TextAreaBox", "BreakNode", "CanvasBox", "Viewport",
):
    CONSOLIDATED_METHOD_MAPPINGS[(_owner_name, "dom_node")] = (
        ("dom_node", "Node"),
    )

for _owner_name in (
    "AudioBox", "VideoBox", "ReplacedBox", "SVGSVGBox", "BreakNode",
):
    CONSOLIDATED_METHOD_MAPPINGS[(_owner_name, "can_have_children")] = (
        ("can_have_children", "Node"),
    )

_NODE_KIND_METHODS: dict[str, str] = {
    "BlockContainer": "is_block_container",
    "Box": "is_box",
    "BreakNode": "is_break_node",
    "FieldSetBox": "is_fieldset_box",
    "InlineNode": "is_inline_node",
    "LegendBox": "is_legend_box",
    "ListItemBox": "is_list_item_box",
    "ReplacedBox": "is_replaced_box",
    "SVGBox": "is_svg_box",
    "SVGClipBox": "is_svg_clip_box",
    "SVGForeignObjectBox": "is_svg_foreign_object_box",
    "SVGGeometryBox": "is_svg_geometry_box",
    "SVGGraphicsBox": "is_svg_graphics_box",
    "SVGMaskBox": "is_svg_mask_box",
    "SVGPatternBox": "is_svg_pattern_box",
    "SVGSVGBox": "is_svg_svg_box",
    "TableWrapper": "is_table_wrapper",
    "TextAreaBox": "is_textarea_box",
    "Viewport": "is_viewport",
}
for _owner_name, _method_name in _NODE_KIND_METHODS.items():
    CONSOLIDATED_METHOD_MAPPINGS[(_owner_name, _method_name)] = (
        (_method_name, "Node"),
    )

CONSOLIDATED_METHOD_MAPPINGS[("Node", "is_node_with_style")] = (
    ("as_node_with_style", "Node"),
)
CONSOLIDATED_METHOD_MAPPINGS[("Node", "is_node_with_style_and_box_model_metrics")] = (
    ("as_node_with_style_and_box_model_metrics", "Node"),
)

for _owner_name in ("AudioBox", "ReplacedBox", "TextInputBox", "TextAreaBox"):
    CONSOLIDATED_METHOD_MAPPINGS[(_owner_name, "has_auto_content_box_size")] = (
        ("has_auto_content_box_size", "Box"),
    )

CONSOLIDATED_METHOD_MAPPINGS[("Box", "compute_auto_content_box_size")] = (
    ("natural_size", "Box"),
)
for _owner_name in ("CanvasBox", "CheckBox", "RadioButton", "TextInputBox", "TextAreaBox"):
    CONSOLIDATED_METHOD_MAPPINGS[(_owner_name, "compute_auto_content_box_size")] = (
        ("new", _owner_name),
    )

# Creation of ordinary and specialized paintables is centralized here. SVG
# resource boxes use their retained clip/mask/pattern collectors because they
# deliberately do not enter the normal BlockBox descendant list.
for _owner_name in (
    "AudioBox", "VideoBox", "FieldSetBox", "SVGSVGBox",
    "SVGForeignObjectBox", "SVGGeometryBox", "SVGGraphicsBox", "SVGImageBox",
    "SVGTextBox", "SVGTextPathBox", "CanvasBox", "CheckBox", "RadioButton",
    "Viewport", "Box", "BlockContainer",
):
    CONSOLIDATED_METHOD_MAPPINGS[(_owner_name, "create_paintable")] = (
        ("block_box_from_typed_layout_with_ancestor", None),
    )
CONSOLIDATED_METHOD_MAPPINGS[("SVGClipBox", "create_paintable")] = (
    ("collect_svg_clip_path_components", None),
)
CONSOLIDATED_METHOD_MAPPINGS[("SVGMaskBox", "create_paintable")] = (
    ("collect_svg_mask_paint_operations", None),
)
CONSOLIDATED_METHOD_MAPPINGS[("SVGPatternBox", "create_paintable")] = (
    ("resolve_svg_pattern_paint_style", None),
)
CONSOLIDATED_METHOD_MAPPINGS[("BlockContainer", "paintable_with_lines")] = (
    ("text_lines_from_typed_layout", None),
)
CONSOLIDATED_METHOD_MAPPINGS[("Box", "paintable_box")] = (
    ("block_box_from_typed_layout_with_ancestor", None),
)
CONSOLIDATED_METHOD_MAPPINGS[("InlineNode", "create_paintable_for_line_with_index")] = (
    ("text_lines_from_typed_layout", None),
)
CONSOLIDATED_METHOD_MAPPINGS[("SVGSVGBox", "natural_size")] = (
    ("negotiate_svg_natural_metrics", None),
)

# The retained V layout tree does not build the parallel GC paintable lists
# owned by C++ Layout::Node. A single DOM bridge lowers that typed tree into the
# active renderer-independent paint transport on every layout. The mappings
# below cover only those list/factory operations; lifecycle hooks with no V
# equivalent intentionally remain visible to the audit.
for _method_name in (
    "add_paintable", "clear_paintables", "create_paintable",
    "first_paintable", "paintables",
):
    CONSOLIDATED_METHOD_MAPPINGS[("Node", _method_name)] = (
        ("materialize_dom_paintables", None),
    )

# Computed-style propagation and anonymous table-wrapper construction are
# operations on ComputedProperties in V rather than virtual NodeWithStyle
# methods. The common Node prefix supplies the type and scrolling queries.
CONSOLIDATED_METHOD_MAPPINGS.update({
    ("NodeWithStyle", "propagate_non_inherit_values"): (
        ("inherit_from_for_layout", "ComputedProperties"),
    ),
    ("NodeWithStyle", "create_anonymous_wrapper"): (
        ("create_anonymous_block_wrapper", None),
    ),
    ("NodeWithStyle", "reset_table_box_computed_values_used_by_wrapper_to_init_values"): (
        ("take_properties_for_table_wrapper", "ComputedProperties"),
    ),
    ("NodeWithStyle", "transfer_table_box_computed_values_to_wrapper_computed_values"): (
        ("take_properties_for_table_wrapper", "ComputedProperties"),
    ),
    ("NodeWithStyle", "is_scroll_container"): (("is_scroll_container", "Node"),),
    ("NodeWithStyle", "mutable_computed_values"): (
        ("set_computed_values", "NodeWithStyle"),
    ),
    ("NodeWithStyle", "background_layers"): (("background_layers", "ComputedValues"),),
    ("NodeWithStyle", "is_body"): (("is_body", "Node"),),
    ("NodeWithStyle", "is_node_with_style"): (("as_node_with_style", "Node"),),
})

# FlexItem and FlexLine are temporary C++ algorithm records. V keeps the same
# values in per-line vectors local to the flex runner: margin-box arithmetic is
# performed while measuring/placing each line and factor sums while resolving
# flexible lengths.
for _method_name in (
    "hypothetical_cross_size_with_margins", "outer_hypothetical_main_size",
    "outer_target_main_size", "outer_flex_base_size",
    "add_main_margin_box_sizes", "add_cross_margin_box_sizes",
):
    CONSOLIDATED_METHOD_MAPPINGS[("FlexItem", _method_name)] = (
        ("run_flex_formatting_context", None),
    )
for _method_name in (
    "sum_of_flex_factor_of_unfrozen_items",
    "sum_of_scaled_flex_shrink_factor_of_unfrozen_items",
):
    CONSOLIDATED_METHOD_MAPPINGS[("FlexLine", _method_name)] = (
        ("resolve_flexible_lengths", None),
    )

# More layout subclasses collapsed into Node's tagged prefix. Content sizing
# and image/font-provider behavior not represented by these common operations
# remain unmatched for later behavioral translation.
for _owner_name in ("NavigableContainerViewport", "TextNode"):
    CONSOLIDATED_METHOD_MAPPINGS[(_owner_name, "dom_node")] = (("dom_node", "Node"),)
CONSOLIDATED_METHOD_MAPPINGS.update({
    ("NavigableContainerViewport", "create_paintable"): (
        ("block_box_from_typed_layout_with_ancestor", None),
    ),
    ("TextNode", "grapheme_segmenter"): (("text_grapheme_boundaries", None),),
    ("TextNode", "line_segmenter"): (("text_line_boundaries", None),),
    ("TextNode", "create_paintable"): (("text_lines_from_typed_layout", None),),
    ("TextNode", "is_text_node"): (("is_text_node", "Node"),),
    ("ImageBox", "natural_size"): (("natural_size", "Box"),),
    ("ImageBox", "create_paintable"): (
        ("block_box_from_typed_layout_with_ancestor", None),
    ),
    ("ImageBox", "image_provider"): (("reset_for_relayout", "ImageBox"),),
    ("ListItemMarkerBox", "create_paintable"): (
        ("block_box_from_typed_layout_with_ancestor", None),
    ),
    ("ListItemMarkerBox", "is_list_item_marker_box"): (
        ("is_list_item_marker_box", "Node"),
    ),
    ("ListItemMarkerBox", "can_have_children"): (("can_have_children", "Node"),),
    ("NodeWithStyleAndBoxModelMetrics", "set_continuation_of_node"): (
        ("clone_inline_node_as_continuation", None),
    ),
    ("NodeWithStyleAndBoxModelMetrics", "is_node_with_style_and_box_model_metrics"): (
        ("as_node_with_style_and_box_model_metrics", "Node"),
    ),
    ("UsedValues", "add_floating_descendant"): (
        ("layout_floating_box", "BlockFormattingContext"),
    ),
    ("UsedValues", "floating_descendants"): (
        ("layout_floating_box", "BlockFormattingContext"),
    ),
    ("Item", "border_box_width"): (("border_box_width", "InlineLevelItem"),),
    ("LineBuilder", "current_block_offset"): (
        ("current_block_offset_value", "LineBuilder"),
    ),
})

# C++ allocates a subclass for each paintable kind. V lowers layout nodes into
# BlockBox/SVGPaintable value records and selects the concrete renderer helper
# while emitting commands. These mappings tie the reviewed factory, accessor,
# reset, and kind-discriminator methods to that live lowering/painting path.
CONSOLIDATED_METHOD_MAPPINGS.update({
    ("SVGForeignObjectPaintable", "create"): (
        ("block_box_from_typed_layout_with_ancestor", None),
    ),
    ("SVGForeignObjectPaintable", "layout_box"): (("layout_box", "SVGPaintable"),),
    ("SVGForeignObjectPaintable", "hit_test"): (("viewport_hit_test", None),),
    ("SVGForeignObjectPaintable", "paint"): (("flat_paint_commands", "BlockBox"),),
    ("SVGSVGPaintable", "create"): (
        ("block_box_from_typed_layout_with_ancestor", None),
    ),
    ("SVGSVGPaintable", "paint_svg_box"): (("paint_commands", "SVGPaintable"),),
    ("SVGSVGPaintable", "paint_descendants"): (("paint_svg_descendants", None),),
    ("SVGSVGPaintable", "is_svg_svg_paintable"): (
        ("layout_debug_paintable_class", None),
    ),
    ("FieldSetPaintable", "create"): (
        ("block_box_from_typed_layout_with_ancestor", None),
    ),
    ("FieldSetPaintable", "layout_box"): (
        ("block_box_from_typed_layout_with_ancestor", None),
    ),
    ("NavigableContainerViewportPaintable", "create"): (
        ("block_box_from_typed_layout_with_ancestor", None),
    ),
    ("NavigableContainerViewportPaintable", "is_navigable_container_viewport_paintable"): (
        ("layout_debug_paintable_class", None),
    ),
    ("NavigableContainerViewportPaintable", "navigable_container"): (
        ("block_box_from_typed_layout_with_ancestor", None),
    ),
    ("PaintableWithLines", "create"): (("text_lines_from_typed_layout", None),),
    ("PaintableWithLines", "reset_for_relayout"): (
        ("text_lines_from_typed_layout", None),
    ),
    ("SVGGraphicsPaintable", "create"): (
        ("block_box_from_typed_layout_with_ancestor", None),
    ),
    ("SVGGraphicsPaintable", "reset_for_relayout"): (
        ("block_box_from_typed_layout_with_ancestor", None),
    ),
    ("SVGGraphicsPaintable", "is_svg_graphics_paintable"): (
        ("layout_debug_paintable_class", None),
    ),
    ("SVGPathPaintable", "create"): (
        ("block_box_from_typed_layout_with_ancestor", None),
    ),
    ("SVGPathPaintable", "reset_for_relayout"): (
        ("set_computed_svg_path", "UsedValues"),
    ),
    ("SVGPathPaintable", "is_svg_path_paintable"): (
        ("layout_debug_paintable_class", None),
    ),
    ("TextPaintable", "create"): (("text_lines_from_typed_layout", None),),
    ("TextPaintable", "layout_node"): (("text_lines_from_typed_layout", None),),
    ("TextPaintable", "is_text_paintable"): (("layout_debug_paintable_class", None),),
    ("ViewportPaintable", "create"): (
        ("block_box_from_typed_layout_with_ancestor", None),
    ),
    ("ViewportPaintable", "reset_for_relayout"): (
        ("viewport_build_stacking_context_tree", None),
    ),
    ("CheckBoxPaintable", "create"): (
        ("block_box_from_typed_layout_with_ancestor", None),
    ),
    ("CheckBoxPaintable", "paint"): (("checkbox_commands", None),),
    ("ImagePaintable", "create"): (
        ("block_box_from_typed_layout_with_ancestor", None),
    ),
    ("MarkerPaintable", "create"): (("flat_paint_commands", "BlockBox"),),
    ("MarkerPaintable", "layout_box"): (("flat_paint_commands", "BlockBox"),),
    ("RadioButtonPaintable", "create"): (
        ("block_box_from_typed_layout_with_ancestor", None),
    ),
    ("RadioButtonPaintable", "paint"): (("radio_button_commands", None),),
    ("SVGClipPaintable", "create"): (("collect_svg_clip_path_components", None),),
    ("SVGClipPaintable", "forms_unconnected_subtree"): (
        ("collect_svg_clip_path_components", None),
    ),
    ("SVGMaskPaintable", "create"): (("collect_svg_mask_paint_operations", None),),
    ("SVGMaskPaintable", "forms_unconnected_subtree"): (
        ("collect_svg_mask_paint_operations", None),
    ),
    ("SVGPatternPaintable", "create"): (("resolve_svg_pattern_paint_style", None),),
    ("SVGPatternPaintable", "forms_unconnected_subtree"): (
        ("resolve_svg_pattern_paint_style", None),
    ),
    ("VideoPaintable", "create"): (
        ("block_box_from_typed_layout_with_ancestor", None),
    ),
    ("CanvasPaintable", "create"): (
        ("block_box_from_typed_layout_with_ancestor", None),
    ),
})

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
    # PaintableFragment is a value record in V. The active layout bridge keeps
    # DOM/layout-only state on TextFragment and embeds the renderer-independent
    # PaintableFragment for geometry, glyph, and selection operations.
    ("PaintableFragment", "layout_node"): (("layout_handle", "TextFragment"),),
    ("PaintableFragment", "start_offset"): (("start_offset", "PaintableFragment"),),
    ("PaintableFragment", "length_in_code_units"): (
        ("length_in_code_units", "PaintableFragment"),
    ),
    ("PaintableFragment", "baseline"): (("baseline", "PaintableFragment"),),
    ("PaintableFragment", "offset"): (("offset", "PaintableFragment"),),
    ("PaintableFragment", "set_offset"): (("offset", "PaintableFragment"),),
    ("PaintableFragment", "size"): (("size", "PaintableFragment"),),
    ("PaintableFragment", "shadows"): (("text_shadows", "TextFragment"),),
    ("PaintableFragment", "set_shadows"): (("text_shadows", "TextFragment"),),
    ("PaintableFragment", "glyph_run"): (("glyph_run", "PaintableFragment"),),
    ("PaintableFragment", "orientation"): (("orientation", "PaintableFragment"),),
    ("PaintableFragment", "width"): (("size", "PaintableFragment"),),
    ("PaintableFragment", "height"): (("size", "PaintableFragment"),),
    ("PaintableFragment", "text"): (("text", "TextFragment"),),
    ("PaintableFragment", "text_decoration_thickness"): (
        ("decoration_thickness", "TextFragment"),
    ),
    ("PaintableFragment", "set_text_decoration_thickness"): (
        ("decoration_thickness", "TextFragment"),
    ),
    ("PaintableFragment", "has_trailing_whitespace"): (
        ("has_trailing_whitespace", "PaintableFragment"),
    ),
    ("ExternalContentSource", "current_bitmap"): (
        ("bitmap_id", "ExternalContentSource"),
    ),
    # Paintable's visibility and stacking bits are retained on each BlockBox.
    # The opaque layout handle replaces the GC reference and lets DOM repaint
    # invalidation recover the exact typed Layout::Node.
    ("Paintable", "is_visible"): (
        ("visible", "BlockBox"),
        ("opacity", "BlockBox"),
    ),
    ("Paintable", "has_stacking_context"): (("stacking_context", "BlockBox"),),
    ("Paintable", "layout_node"): (("layout_handle", "BlockBox"),),
    # The former flat fragment vector is grouped by line in the active paint
    # transport. Both accessors expose that retained collection, and the type
    # discriminator is stored beside it for cursor-phase dispatch.
    ("PaintableWithLines", "fragments"): (("lines", "BlockBox"),),
    ("PaintableWithLines", "is_paintable_with_lines"): (
        ("paintable_with_lines", "BlockBox"),
    ),
    # PaintableBox's remaining value state is carried directly by the active
    # BlockBox or by layout's UsedValues record. Mappings with several fields
    # require every component of the former C++ aggregate to remain present.
    ("PaintableBox", "box_model"): (
        ("margin", "BlockBox"),
        ("border", "BlockBox"),
        ("padding", "BlockBox"),
    ),
    ("PaintableBox", "absolute_x"): (("x", "BlockBox"),),
    ("PaintableBox", "absolute_y"): (("y", "BlockBox"),),
    ("PaintableBox", "absolute_position"): (("x", "BlockBox"), ("y", "BlockBox")),
    ("PaintableBox", "has_css_transform"): (("own_paint_transform", "BlockBox"),),
    ("PaintableBox", "set_override_borders_data"): (
        ("override_borders_data_", "UsedValues"),
    ),
    ("PaintableBox", "set_table_cell_coordinates"): (
        ("table_cell_coordinates_", "UsedValues"),
    ),
    ("PaintableBox", "set_filter"): (("filter", "BlockBox"),),
    ("PaintableBox", "filter"): (("filter", "BlockBox"),),
    ("PaintableBox", "set_used_values_for_grid_template_columns"): (
        ("used_grid_template_columns", "UsedValues"),
    ),
    ("PaintableBox", "used_values_for_grid_template_columns"): (
        ("used_grid_template_columns", "UsedValues"),
    ),
    ("PaintableBox", "set_used_values_for_grid_template_rows"): (
        ("used_grid_template_rows", "UsedValues"),
    ),
    ("PaintableBox", "used_values_for_grid_template_rows"): (
        ("used_grid_template_rows", "UsedValues"),
    ),
    ("PaintableBox", "set_own_scroll_frame_index"): (
        ("own_scroll_frame_index", "BlockBox"),
    ),
    ("PaintableBox", "own_scroll_frame_index"): (
        ("own_scroll_frame_index", "BlockBox"),
    ),
    ("PaintableBox", "set_accumulated_visual_context"): (
        ("accumulated_visual_context_index", "BlockBox"),
    ),
    ("PaintableBox", "accumulated_visual_context_index"): (
        ("accumulated_visual_context_index", "BlockBox"),
    ),
    ("PaintableBox", "set_accumulated_visual_context_for_descendants"): (
        ("accumulated_visual_context_for_descendants_idx", "BlockBox"),
    ),
    ("PaintableBox", "accumulated_visual_context_for_descendants_index"): (
        ("accumulated_visual_context_for_descendants_idx", "BlockBox"),
    ),
    ("PaintableBox", "scrollbar"): (
        ("horizontal_scrollbar", "BlockBox"),
        ("vertical_scrollbar", "BlockBox"),
    ),
    ("PaintableBox", "ensure_scrollbar"): (
        ("horizontal_scrollbar", "BlockBox"),
        ("vertical_scrollbar", "BlockBox"),
    ),
    ("PaintableBox", "set_stacking_context"): (("stacking_context", "BlockBox"),),
    ("PaintableBox", "invalidate_stacking_context"): (
        ("stacking_context_tree_is_valid", "DocumentLayoutResult"),
    ),
    ("PaintableBox", "set_overflow_data"): (
        ("scrollable_overflow_rect_", "UsedValues"),
        ("has_scrollable_overflow_", "UsedValues"),
    ),
    ("PaintableBox", "outline_offset"): (("outline_offset", "BlockBox"),),
    # Upstream caches a vector per box/phase. The active V bridge flattens those
    # vectors into phase buckets plus per-entry validity bits on the layout
    # result, retaining the same selective invalidation behavior.
    ("PaintableBox", "has_cached_commands"): (
        ("paint_phase_commands", "DocumentLayoutResult"),
        ("paint_phase_entry_valid", "DocumentLayoutResult"),
    ),
    ("PaintableBox", "cached_commands"): (
        ("paint_phase_commands", "DocumentLayoutResult"),
    ),
    ("PaintableBox", "set_cached_commands"): (
        ("paint_phase_commands", "DocumentLayoutResult"),
        ("paint_phase_entry_valid", "DocumentLayoutResult"),
    ),
}

# Some V modules deliberately consolidate private C++ helpers into a shared
# implementation or give them a module-specific prefix to avoid collisions.
# These mappings are source-qualified and are accepted only while every named
# V target still exists, so they cannot silently turn stale documentation into
# coverage.
CONSOLIDATED_FUNCTION_MAPPINGS: dict[tuple[str, str], tuple[str, ...]] = {
    ("LayoutState.cpp", "build_paint_tree"): ("block_box_from_typed_layout",),
    ("SVGFormattingContext.cpp", "is_container_element"): ("layout_container_element",),
    ("GridFormattingContext.cpp", "gap_to_px"): ("resolve_layout_gap",),
    ("GridFormattingContext.cpp", "to_alignment"): (
        "grid_inline_alignment",
        "grid_block_alignment",
    ),
    ("TableFormattingContext.cpp", "width_is_auto_or_indefinite_percentage"): (
        "calculate_table_grid_intrinsic_widths",
    ),
    ("TableFormattingContext.cpp", "compute_columns_total_candidate_width"): (
        "table_columns_total_width",
    ),
    ("FlexFormattingContext.cpp", "gap_to_px"): (
        "flex_formatting_context_main_gap",
        "flex_formatting_context_cross_gap",
    ),
    # TreeBuilder's file-local predicates and sequence wrapper were retained in
    # the recursive builder/table-fixup split under unambiguous table-prefixed
    # names.
    ("TreeBuilder.cpp", "has_inline_or_in_flow_block_children"): (
        "attach_children_maintaining_inline_invariant",
    ),
    ("TreeBuilder.cpp", "has_in_flow_block_children"): (
        "attach_children_maintaining_inline_invariant",
    ),
    ("TreeBuilder.cpp", "insertion_parent_for_inline_node"): (
        "attach_children_maintaining_inline_invariant",
    ),
    ("TreeBuilder.cpp", "insertion_parent_for_block_node"): (
        "attach_children_maintaining_inline_invariant",
    ),
    ("TreeBuilder.cpp", "is_ignorable_whitespace"): ("ignorable_table_whitespace",),
    ("TreeBuilder.cpp", "is_table_track"): ("proper_table_child",),
    ("TreeBuilder.cpp", "is_table_track_group"): ("table_track_group",),
    ("TreeBuilder.cpp", "is_proper_table_child"): ("proper_table_child",),
    ("TreeBuilder.cpp", "is_not_proper_table_child"): ("table_not_proper_child",),
    ("TreeBuilder.cpp", "is_not_table_row"): ("table_not_row",),
    ("TreeBuilder.cpp", "is_not_table_cell"): ("table_not_cell",),
    ("TreeBuilder.cpp", "is_table_row_group_column_group_or_caption"): (
        "generate_missing_table_parents",
    ),
    ("TreeBuilder.cpp", "for_each_sequence_of_consecutive_children_matching"): (
        "wrap_table_child_sequences",
    ),
    ("TreeBuilder.cpp", "wrap_in_anonymous"): ("anonymous_table_box",),
    ("TreeBuilder.cpp", "fixup_row"): ("append_missing_table_cells",),
    # Shadow placement is folded into the live CSS-to-painting transport
    # conversion rather than exposed as a one-line enum helper.
    ("ShadowData.h", "shadow_placement_from_css"): (
        "painting_shadow_data_from_transport",
    ),
    ("DisplayList.cpp", "command_bounding_rectangle"): ("command_bounding_rect",),
    ("Paintable.cpp", "normalize_border_radii_data"): (
        "paintable_box_border_radii_data",
    ),
    # Text decoration metrics and resolved shadows are attached while committed
    # line fragments are lowered, before the foreground span painter consumes
    # them. This is the same work as the former pre-paint mutation pass.
    ("PaintableWithLines.cpp", "resolve_text_fragment_properties"): (
        "computed_text_decoration_thickness",
        "computed_text_shadows",
        "text_lines_from_typed_layout",
    ),
    ("ViewportPaintable.cpp", "effective_css_clip_rect"): (
        "paintable_box_get_clip_rect",
    ),
    ("ViewportPaintable.cpp", "compute_clip_data"): (
        "compatibility_overflow_clip",
    ),
    ("TableBordersPainting.cpp", "collect_cell_boxes"): ("collect_table_cells",),
    ("BackgroundPainting.cpp", "resolve_background_layers"): (
        "resolve_background_layer",
        "resolve_background_layer_without_intrinsic",
    ),
    ("SVGMaskable.cpp", "first_child_layout_node_of_type"): (
        "svg_url_mask_for_box",
        "svg_url_clip_path_for_box",
    ),
    ("SVGMaskable.cpp", "get_mask_box"): ("svg_url_mask_for_box",),
    ("SVGMaskable.cpp", "get_clip_box"): ("svg_url_clip_path_for_box",),
    ("SVGMaskable.cpp", "mask_type_to_gfx_mask_kind"): ("svg_url_mask_for_box",),
    ("SVGMaskable.cpp", "paint_mask_or_clip_to_display_list"): (
        "svg_url_mask_for_box",
        "svg_url_clip_path_for_box",
    ),
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
