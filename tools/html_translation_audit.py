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
    # C++ needs this self-upcast for its generated WebIDL property mixin. V's
    # CSSStyleProperties record implements those entry points directly.
    ("CSSStyleProperties", "generated_style_properties_to_css_style_properties"),
    # Parser/FontComputer/Screen retain their owner through JS realm and Window
    # edges in C++. V passes the document dependency explicitly and does not
    # reproduce those GC ownership accessors in the typed engine.
    ("FontComputer", "document"),
    ("Parser", "window"),
    ("Parser", "realm"),
    ("Screen", "window"),
    ("Client", "image_style_value_finalize"),
    # Rust's generated SVG bindings read these C++ offsetof constants while
    # tracing wrapper fields. V's native records expose the typed fields
    # directly and have no ABI offset bridge.
    ("SVGAnimatedLength", "base_val_offset"),
    ("SVGAnimatedLength", "anim_val_offset"),
    ("SVGAnimatedLengthList", "base_val_offset"),
    ("SVGAnimatedNumberList", "base_val_offset"),
    ("SVGAnimatedTransformList", "base_val_offset"),
    ("SVGAnimatedTransformList", "anim_val_offset"),
    # Upstream retains an empty virtual initialization hook on foreignObject.
    # V's tagged DOM element needs no subclass allocation step for it.
    ("SVGForeignObjectElement", "initialize_element"),

    # WebAudio keeps its typed graph independent of the JS realm and DOM event
    # wrappers. These accessors and dispatch bridges exist only to recover the
    # owning JS/Window objects in the C++ embedding.
    ("AudioNode", "relevant_global_object"),
    ("BaseAudioContext", "relevant_settings_object"),
    ("BaseAudioContext", "relevant_global_object"),
    ("BaseAudioContext", "relevant_global_event_target"),
    ("BaseAudioContext", "create_associated_event"),
    ("BaseAudioContext", "relevant_window"),
    # V's offline renderer executes on the deterministic engine thread, so its
    # completion/suspension callbacks need no cross-thread event-loop hop.
    ("OfflineAudioRenderer", "post_to_control_thread"),
    # ComputedFilterView retains a Rust-owned StyleValue handle while lowering
    # the FFI record. V stores the typed FilterStyleValue sum directly.
    ("ComputedFilterView", "retained_style_value"),
}
RUNTIME_ONLY_FREE_FUNCTIONS = {
    # The standalone parser has no process-global internal JS realm; its
    # parsing document and URL context are carried by ParsingParams instead.
    ("Parser/Helpers.cpp", "internal_css_realm"),
    # Ladybird's C++ SVG entry points construct a borrowed string descriptor
    # solely for the Rust parser ABI. V parses its native strings directly.
    ("AttributeParsing.cpp", "ffi_svg_input"),
    ("Path.cpp", "ffi_svg_input"),
    # SVGFilterElement builds this borrowed UTF-16 descriptor only to pass
    # attribute values through the Rust filter-graph ABI. V lowers its native
    # strings directly while constructing FilterGraph.
    ("SVGFilterElement.cpp", "view_of"),
    # AudioBuffer channel views are native V slices. C++ needs weak JS caches
    # to preserve SameObject per realm and detach ArrayBuffers on acquisition;
    # V preserves the playback snapshot directly in AudioBufferContents.
    ("AudioBuffer.cpp", "audio_buffer_channel_data_caches"),
    ("AudioBuffer.cpp", "prune_audio_buffer_channel_data_caches"),
    ("AudioBuffer.cpp", "cache_for"),
    ("AudioBuffer.cpp", "prune_live_channel_views"),
    # These helpers only wrap typed AudioBuffer/AudioParam values for JS and
    # invoke WebIDL callbacks/promises in the relevant realm.
    ("AudioParamMap.cpp", "wrapped_param"),
    ("BaseAudioContext.cpp", "audio_buffer"),
    ("BaseAudioContext.cpp", "invoke_audio_buffer_callback"),
    ("BaseAudioContext.cpp", "invoke_error_callback"),
    ("BaseAudioContext.cpp", "resolve_audio_buffer_promise"),
}
LANGUAGE_ARTIFACT_FREE_FUNCTIONS = {
    # V string literals already have their runtime representation; this C++
    # template exists only to form a Utf16View over a char16_t array.
    ("StateAndProperties.cpp", "utf16_view"),
    # BindingsGlue's pointer overload only converts a nullable GC pointer to
    # the non-null wrapper overload; V optionals narrow directly at the call.
    ("BindingsGlue.h", "webgl_wrappable"),
    # V strings do not distinguish an owning Utf16String from a borrowed
    # Utf16View. The editing callers pass the optional string directly, so the
    # C++ lifetime adapter has no executable counterpart in the translation.
    ("Internal/Algorithms.cpp", "optional_utf16_view"),
}
LANGUAGE_ARTIFACT_METHODS = {
    # These are constructor initializer-list and macro-parameter fragments
    # which the deliberately lightweight header scanner sees as methods.
    ("FitContentStyleValue", "StyleValue"),
    ("URLStyleValue", "StyleValueWithDefaultOperators"),
    ("StyleValue", "snake_case"),
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
    # Fetch's filtered response subclasses only constrain which fields are
    # visible. The V port keeps those views in one Response record so cloned
    # metadata and delivery state remain shared with the internal response.
    "FilteredResponse": ("Response",),
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
    # The transport-facing subclass only specializes string/pointer marshaling.
    # V keeps those methods on the shared proxy record with the batching state.
    "WebGLContextProxy": ("WebGLContextProxyBase",),
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
    "SVGLengthValue": ("SvgLengthValue",),
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
    # V dispatches anchor activation and style-element lifecycle hooks through
    # the tagged DOM Element/EventTarget records. Keep both the generic hook
    # and the concrete delegated algorithm visible to the coverage audit.
    ("HTMLAnchorElement", "activation_behavior"): (
        ("activation_behavior", "EventTarget"),
        ("activate_the_hyperlink", "Element"),
    ),
    ("HTMLStyleElement", "children_changed"): (
        ("children_changed", "Element"),
        ("update_a_style_block_for_dynamic_change", "StyleElementBase"),
    ),
    ("HTMLStyleElement", "inserted"): (
        ("inserted", "Element"),
        ("update_a_style_block_for_dynamic_change", "StyleElementBase"),
    ),
    ("HTMLStyleElement", "removed_from"): (
        ("removed_from", "Element"),
        ("update_a_style_block_for_dynamic_change", "StyleElementBase"),
    ),
    ("HTMLStyleElement", "attribute_changed"): (
        ("attribute_changed", "Element"),
        ("style_element_attribute_changed", "StyleElementBase"),
    ),
    ("HTMLStyleElement", "contributes_a_script_blocking_style_sheet"): (
        ("contributes_a_script_blocking_style_sheet", "Element"),
        (
            "style_element_contributes_a_script_blocking_style_sheet",
            "StyleElementBase",
        ),
    ),
    # LocalNavigable is represented by NavigableModel in V. Keep this mapping
    # narrow: only the translated response-download operations live there.
    ("LocalNavigable", "start_download_for_response"): (
        ("start_download_for_response", "NavigableModel"),
    ),
    ("LocalNavigable", "handle_as_a_download"): (
        ("handle_as_a_download", "NavigableModel"),
    ),
    # Macro/variant constructor spellings are not valid V method identifiers;
    # they map to the equivalent tagged-value operations.
    ("StyleValue", "__ENUMERATE_CSS_STYLE_VALUE_TYPE"): (("type_", "StyleValue"),),
    ("ComponentValue", "Token"): (("from_token", "ComponentValue"),),
    # The C++ base owns a virtual inactive-document hook. V keeps the two
    # concrete context lifecycles explicit so neither renderer can be omitted.
    ("BaseAudioContext", "document_became_inactive"): (
        ("document_became_inactive", "AudioContext"),
        ("document_became_inactive", "OfflineAudioContext"),
    ),
    # V flattens AudioWorkletPipe::Config into a module-level typed config.
    ("Config", "ring_sizing_for_device_latency"): (
        ("ring_sizing_for_device_latency", "AudioWorkletPipeConfig"),
    ),
    # WebGL's template helpers are free functions in V because BufferSource and
    # string conversion do not require context state after type narrowing.
    ("WebGLRenderingContextBase", "with_buffer_source_bytes"): (
        ("with_buffer_source_bytes", None),
    ),
    ("WebGLRenderingContextBase", "span_from_typed_array"): (
        ("span_from_typed_array", None),
    ),
    ("WebGLRenderingContextBase", "null_terminated_utf8_string"): (
        ("null_terminated_utf8_string", None),
    ),
    ("WebGLRenderingContextBase", "utf16_string_from_gl_string"): (
        ("utf16_string_from_gl_string", None),
    ),
    # CSS owns ComputedProperties in the V module graph, so the SVG class
    # overrides are dispatched together at the style-computation boundary.
    ("SVGElement", "adjust_computed_style"): (("adjust_element_computed_style", None),),
    ("SVGSymbolElement", "adjust_computed_style"): (("adjust_element_computed_style", None),),
    # The tagged portable SVG Element record implements the specialized
    # subclass identity hooks by inspecting its local tag name.
    ("SVGClipPathElement", "is_svg_clip_path_element"): (
        ("is_svg_clip_path_element", "Element"),
    ),
    ("SVGGradientElement", "is_svg_gradient_element"): (
        ("is_svg_gradient_element", "Element"),
    ),
    ("SVGImageElement", "is_svg_image_element"): (
        ("is_svg_image_element", "Element"),
    ),
    ("SVGPatternElement", "is_svg_pattern_element"): (
        ("is_svg_pattern_element", "Element"),
    ),
    ("SVGSwitchElement", "is_svg_switch_element"): (
        ("is_svg_switch_element", "Element"),
    ),
    # Both the SVGElement cache owner and filter-primitive mixin use the same
    # live reflected-length factory on V's tagged Element record.
    ("SVGElement", "svg_animated_length_for_attribute"): (
        ("svg_animated_length_for_attribute", "Element"),
    ),
    ("SVGFilterPrimitiveStandardAttributes", "svg_animated_length_for_attribute"): (
        ("svg_animated_length_for_attribute", "Element"),
    ),
    # Resource boxes are attached below their referencing graphics elements.
    # The DOM-owned V element keeps the same reverse dependency and exposes
    # explicit SVG-prefixed invalidation entry points to the layout builder.
    ("SVGElement", "register_resource_box_referencing_element"): (
        ("register_svg_resource_box_referencing_element", "Element"),
    ),
    ("SVGElement", "mark_resource_box_referencing_elements_for_layout_tree_update"): (
        ("mark_svg_resource_box_referencing_elements_for_layout_tree_update", "Element"),
    ),
    ("SVGElement", "mark_resource_box_referencing_elements_for_layout_update"): (
        ("mark_svg_resource_box_referencing_elements_for_layout_update", "Element"),
    ),
    # Paint-server URL resolution is shared by the typed gradient/pattern
    # lowering path. Its fragment helper preserves the document lookup and
    # containing-use-shadow fallback from SVGGraphicsElement.
    ("SVGGraphicsElement", "paint_server_element"): (
        ("resolve_svg_linear_gradient_paint_style", None),
        ("resolve_svg_radial_gradient_paint_style", None),
        ("resolve_svg_pattern_paint_style", None),
    ),
    ("SVGGraphicsElement", "resolve_fragment_identifier_to_element"): (
        ("resolve_svg_fragment_identifier_to_element", None),
    ),
    # The C++ layout FFI pushes gradient/pattern records incrementally. V's
    # paint adapter resolves the same inherited resource state directly into
    # renderer-independent paint-style records.
    ("SVGGradientElement", "push_color_stops"): (
        ("svg_gradient_stops", None),
    ),
    ("SVGGradientElement", "base_paint_server_description"): (
        ("svg_gradient_units", None),
        ("svg_gradient_spread", None),
        ("svg_gradient_transform", None),
        ("svg_gradient_color_space", None),
    ),
    ("SVGLinearGradientElement", "push_paint_server_description"): (
        ("resolve_svg_linear_gradient_paint_style", None),
    ),
    ("SVGRadialGradientElement", "push_paint_server_description"): (
        ("resolve_svg_radial_gradient_paint_style", None),
    ),
    ("SVGPatternElement", "push_paint_server_description"): (
        ("resolve_svg_pattern_paint_style", None),
    ),
    # C++ serializes each primitive into an opaque Rust sink. V's direct graph
    # lowering returns the equivalent typed FilterGraph without an ABI sink.
    ("SVGFilterElement", "push_primitives"): (("gfx_filter", "Element"),),
    # SVGUseElement's C++ registry is replaced by live document traversal in
    # V. Creation installs the UA shadow root, document completion refreshes
    # deferred forward references, and mutation/removal traversals notify the
    # matching use elements without retaining document-specific list nodes.
    ("SVGUseElement", "initialize_element"): (
        ("attach_a_user_agent_shadow_root", "Element"),
        ("refresh_svg_use_shadow_trees", "Document"),
    ),
    ("SVGUseElement", "register_for_referenced_element_changes"): (
        ("update_use_elements_that_reference_this", "Element"),
    ),
    ("SVGUseElement", "unregister_for_referenced_element_changes"): (
        ("remove_from_use_element_that_reference_this", "Element"),
    ),
    ("SVGUseElement", "href_value"): (("svg_use_href", "Element"),),
    ("SVGUseElement", "additional_element_transform"): (
        ("svg_transform_element_model", None),
    ),
    ("SVGUseElement", "svg_element_changed_before_document_complete"): (
        ("refresh_svg_use_shadow_trees", "Document"),
    ),
    # The fit-to-viewBox subclasses all delegate their initialization to the
    # same translated value owner. V value defaults also keep the reflected
    # AnimatedRect nulled before a valid viewBox is parsed.
    ("SVGPatternElement", "initialize_element"): (
        ("initialize_fit_to_view_box", "FitToViewBox"),
    ),
    ("SVGSVGElement", "initialize_element"): (
        ("initialize_fit_to_view_box", "FitToViewBox"),
    ),
    ("SVGSymbolElement", "initialize_element"): (
        ("initialize_fit_to_view_box", "FitToViewBox"),
    ),
    ("SVGViewElement", "initialize_element"): (
        ("initialize_fit_to_view_box", "FitToViewBox"),
    ),
    # The V transform model combines the base element transform with subclass
    # additions; the base SVGGraphicsElement contribution is the identity.
    ("SVGGraphicsElement", "additional_element_transform"): (
        ("element_transform", None),
    ),
    # SVG root natural sizing parses absolute width/height lengths through the
    # shared unit-aware helper and ignores percentages/auto like upstream.
    ("SVGSVGElement", "width_attribute_length"): (("svg_absolute_length", None),),
    ("SVGSVGElement", "height_attribute_length"): (("svg_absolute_length", None),),
    # Tagged SVG elements select their concrete layout node at the tree-builder
    # boundary. The image provider reads the same retained DOM layout bridge;
    # decoded content updates invalidate that node through its standard hook.
    ("SVGSwitchElement", "create_layout_node"): (
        ("create_layout_node_for_svg_element", None),
    ),
    ("SVGImageElement", "image_provider_layout_node"): (
        ("unsafe_layout_node", "Node"),
    ),
    ("SVGImageElement", "decoded_image_data_did_update"): (
        ("set_needs_layout_update", "Node"),
    ),
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
    # SVG's portable scalar record cannot import CSS without a module cycle.
    # Layout owns the direct CSS-to-SVG conversion. Its serializer reads the
    # same typed length/percentage state directly instead of constructing
    # temporary CSS value wrappers for to_length()/to_percentage().
    ("SVGLengthValue", "from_style_value"): (
        ("svg_length_value_from_style_value", None),
    ),
    ("SVGLengthValue", "to_utf16_string"): (("to_string", "SvgLengthValue"),),
    ("SVGLengthValue", "to_length"): (("to_string", "SvgLengthValue"),),
    ("SVGLengthValue", "to_percentage"): (("to_string", "SvgLengthValue"),),
    # SVGLength stores scalar and canonical non-scalar forms separately in V;
    # reading its internal tagged value is therefore split across two helpers.
    ("SVGLength", "internal_value"): (
        ("svg_length_scalar", None),
        ("svg_length_non_scalar", None),
    ),
    # V keeps the per-use SVG image color scheme on its isolated Document,
    # beside the media-query and style invalidation state that consumes it.
    ("SVGDecodedImageData", "color_scheme"): (
        ("svg_image_color_scheme", "Document"),
    ),
    # SVG presentation attributes are recomputed directly into the V cascade
    # instead of retaining a per-element parsed-property cache. Attribute
    # mutation invalidates style, and the next cascade collects and parses the
    # current attribute set through these concrete functions.
    ("SVGElement", "apply_presentational_hints"): (
        ("collect_svg_presentational_hints", None),
    ),
    ("SVGElement", "presentation_attribute_style"): (
        ("collect_svg_presentational_hints", None),
    ),
    ("SVGElement", "parse_presentation_attribute"): (
        ("parse_svg_presentation_attribute_value", None),
    ),
    ("SVGElement", "update_presentation_attribute_style"): (
        ("attribute_changed", "Element"),
        ("collect_svg_presentational_hints", None),
    ),
    ("SVGElement", "publish_presentation_attribute_style"): (
        ("compute_cascaded_values", "StyleComputer"),
        ("collect_svg_presentational_hints", None),
    ),
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

# Editing's five primitive C++ command subclasses share one tagged EditCommand
# in V. The common apply/unapply/reapply dispatch preserves the subclass bodies;
# private helpers and inline accessors retain explicit targets so this coverage
# fails open if the consolidated implementation is renamed or removed.
for _editing_command_owner in (
    "InsertNodeCommand",
    "RemoveNodeCommand",
    "ReplaceDataCommand",
    "SplitTextCommand",
    "SetAttributeCommand",
):
    for _editing_command_method in ("apply", "unapply", "reapply"):
        CONSOLIDATED_METHOD_MAPPINGS[
            (_editing_command_owner, _editing_command_method)
        ] = ((_editing_command_method, "EditCommand"),)

CONSOLIDATED_METHOD_MAPPINGS.update({
    ("RemoveNodeCommand", "is_lasting_node_removal"): (
        ("is_lasting_node_removal", "EditCommand"),
    ),
    ("ReplaceDataCommand", "replay"): (("replay_data", "EditCommand"),),
    ("ReplaceDataCommand", "node"): (("node", "EditCommand"),),
    ("ReplaceDataCommand", "offset"): (("offset", "EditCommand"),),
    ("ReplaceDataCommand", "removed_data"): (("removed_data", "EditCommand"),),
    ("SetAttributeCommand", "set_or_remove"): (
        ("set_or_remove_attribute", "EditCommand"),
    ),
    ("EditingHistory", "create"): (("new", "EditingHistory"),),
    ("Document", "editing_history"): (("install_editing_history", None),),
    ("ReplacementEndpoints", "relocate_for_merging_left_text_into_right"): (
        ("relocate_for_merging_left_text_into_right", None),
    ),
    ("ReplacementEndpoints", "relocate_for_merging_right_text_into_left"): (
        ("relocate_for_merging_right_text_into_left", None),
    ),
    # The V ImageBox queries the concrete img/input models at its retained
    # layout boundary and stores the resulting paint fallback state directly.
    # Generated, object, and SVG providers keep the upstream default of not
    # pending.
    ("ImageProvider", "is_image_pending"): (("element_image_is_pending", None),),
    ("ImageProvider", "renders_as_alt_text"): (
        ("renders_as_alt_text", "ImageBox"),
    ),
})

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
    "compute_row_content_height": (("compute_table_row_minimum_heights", None),),
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

# CalculatedStyleValue.cpp models a calculation as a deep virtual class tree;
# V keeps the same typed operations on a CalcNode sum type. This first
# reconciliation slice covers the common node infrastructure, numeric leaves,
# sum/product/negation, random(), and abs/sign/sin/cos. Each target below is an
# active parser, simplifier, resolver, serializer, equality, or Typed OM path.
CONSOLIDATED_METHOD_MAPPINGS.update({
    ("CalculationNode", "from_style_value"): (
        ("calculation_node_from_numeric_primitive", None),
        ("calculation_node_from_calc", None),
    ),
    ("CalculationNode", "is_operator_node"): (("serialize_a_calculation_tree", None),),
    ("CalculationNode", "is_math_function_node"): (("serialize_a_calculation_tree", None),),
    ("CalculationNode", "is_calc_operator_node"): (("serialize_a_calculation_tree", None),),
    ("CalculationNode", "run_operation_if_possible"): (("resolve_calc_node", None),),
    ("CalculationNode", "reify"): (("reify_calc_node", None),),
    ("CalculatedStyleValue", "equals"): (("equals", "StyleValue"),),
    ("CalculatedStyleValue", "reify"): (("reify_calc_node", None),),
    ("CalculatedStyleValue", "resolves_to_angle_percentage"): (
        ("matches_angle_percentage", "NumericType"),
    ),
    ("CalculatedStyleValue", "resolves_to_flex"): (("matches_flex", "NumericType"),),
    ("CalculatedStyleValue", "resolves_to_frequency"): (
        ("matches_frequency", "NumericType"),
    ),
    ("CalculatedStyleValue", "resolves_to_frequency_percentage"): (
        ("matches_frequency_percentage", "NumericType"),
    ),
    ("CalculatedStyleValue", "resolves_to_resolution"): (
        ("matches_resolution", "NumericType"),
    ),
    ("CalculatedStyleValue", "resolves_to_time"): (("matches_time", "NumericType"),),
    ("CalculatedStyleValue", "resolves_to_time_percentage"): (
        ("matches_time_percentage", "NumericType"),
    ),
    ("CalculatedStyleValue", "resolves_to_dimension"): (
        ("matches_dimension", "NumericType"),
    ),
    ("NumericCalculationNode", "from_keyword"): (("calc_constant_from_ident", None),),
    ("NumericCalculationNode", "serialize_value"): (
        ("serialize_numeric_value", "CalcNumeric"),
    ),
    ("NumericCalculationNode", "value_to_string"): (("serialize_leaf", "CalcNumeric"),),
    ("NumericCalculationNode", "is_in_canonical_unit"): (
        ("is_canonical", "CalcNumeric"),
    ),
    ("NumericCalculationNode", "infinite_or_nan_value"): (
        ("non_finite_keyword", "CalcNumeric"),
    ),
    ("NumericCalculationNode", "is_negative"): (("serialize_calc_sum", None),),
    ("NumericCalculationNode", "negated"): (("simplify_calc_negate", None),),
    ("NumericCalculationNode", "equals"): (("equals", "StyleValue"),),
    ("NumericCalculationNode", "reify"): (("reify_calc_node", None),),
    ("NumericCalculationNode", "with_simplified_children"): (
        ("canonicalize_calc_leaf", None),
    ),
    ("NumericCalculationNode", "children"): (("numeric_type", "CalcNode"),),
    ("RandomCalculationNode", "with_simplified_children"): (("simplify_calc", None),),
    ("RandomCalculationNode", "run_operation_if_possible"): (
        ("resolve_calc_random", None),
    ),
    ("RandomCalculationNode", "equals"): (("equals", "StyleValue"),),
    ("CalculationResult", "from_value"): (("resolve_calc_leaf", None),),
    ("CalculationResult", "add"): (("calc_result_add", None),),
    ("CalculationResult", "subtract"): (
        ("calc_result_add", None),
        ("simplify_calc_negate", None),
    ),
    ("CalculationResult", "multiply_by"): (("calc_result_multiply", None),),
    ("CalculationResult", "divide_by"): (
        ("calc_result_multiply", None),
        ("inverted", "NumericType"),
    ),
    ("CalculationResult", "negate"): (("resolve_calc_node", None),),
    ("CalculationResult", "invert"): (("resolve_calc_node", None),),
    ("MinCalculationNode", "reify"): (("reify_calc_node", None),),
    ("MaxCalculationNode", "reify"): (("reify_calc_node", None),),
    ("ClampCalculationNode", "reify"): (("reify_calc_node", None),),
    ("NonMathFunctionCalculationNode", "create"): (
        ("resolve_to_calculation_node", "TreeCountingFunctionStyleValue"),
    ),
    ("NonMathFunctionCalculationNode", "contains_percentage"): (
        ("numeric_type", "CalcNode"),
    ),
    ("NonMathFunctionCalculationNode", "with_simplified_children"): (
        ("simplify_calc", None),
    ),
    ("NonMathFunctionCalculationNode", "children"): (("numeric_type", "CalcNode"),),
    ("NonMathFunctionCalculationNode", "dump"): (
        ("serialize_a_calculation_tree", None),
    ),
    ("NonMathFunctionCalculationNode", "equals"): (("equals", "StyleValue"),),
})

_CALC_OPERATOR_METHOD_TARGETS: dict[str, dict[str, tuple[tuple[str, str | None], ...]]] = {
    "SumCalculationNode": {
        "create": (("simplify_calc_sum", None),),
        "contains_percentage": (("numeric_type", "CalcNode"),),
        "with_simplified_children": (("simplify_calc_sum", None),),
        "dump": (("serialize_calc_sum", None),),
        "equals": (("equals", "StyleValue"),),
        "reify": (("reify_calc_node", None),),
    },
    "ProductCalculationNode": {
        "create": (("simplify_calc_product", None),),
        "contains_percentage": (("numeric_type", "CalcNode"),),
        "with_simplified_children": (("simplify_calc_product", None),),
        "dump": (("serialize_calc_product", None),),
        "equals": (("equals", "StyleValue"),),
        "reify": (("reify_calc_node", None),),
    },
    "NegateCalculationNode": {
        "create": (("simplify_calc_negate", None),),
        "contains_percentage": (("numeric_type", "CalcNode"),),
        "with_simplified_children": (("simplify_calc_negate", None),),
        "dump": (("serialize_a_calculation_tree", None),),
        "equals": (("equals", "StyleValue"),),
        "reify": (("reify_calc_node", None),),
    },
    "InvertCalculationNode": {
        "create": (("simplify_calc_invert", None),),
        "contains_percentage": (("numeric_type", "CalcNode"),),
        "with_simplified_children": (("simplify_calc_invert", None),),
        "dump": (("serialize_a_calculation_tree", None),),
        "equals": (("equals", "StyleValue"),),
        "reify": (("reify_calc_node", None),),
    },
}
for _owner_name, _method_mappings in _CALC_OPERATOR_METHOD_TARGETS.items():
    for _method_name, _targets in _method_mappings.items():
        CONSOLIDATED_METHOD_MAPPINGS[(_owner_name, _method_name)] = _targets

for _owner_name in (
    "AbsCalculationNode", "SignCalculationNode", "SinCalculationNode",
    "CosCalculationNode", "TanCalculationNode", "AsinCalculationNode",
    "AcosCalculationNode", "AtanCalculationNode", "Atan2CalculationNode",
    "PowCalculationNode", "SqrtCalculationNode", "LogCalculationNode",
    "ExpCalculationNode", "RoundCalculationNode", "ModCalculationNode",
    "RemCalculationNode", "MinCalculationNode", "MaxCalculationNode",
    "ClampCalculationNode", "HypotCalculationNode",
):
    CONSOLIDATED_METHOD_MAPPINGS.update({
        (_owner_name, "create"): (("build_calc_function", None),),
        (_owner_name, "contains_percentage"): (("numeric_type", "CalcNode"),),
        (_owner_name, "with_simplified_children"): (("simplify_calc_function", None),),
        (_owner_name, "run_operation_if_possible"): (("resolve_calc_function", None),),
        (_owner_name, "dump"): (("serialize_function", "CalcFunction"),),
        (_owner_name, "equals"): (("equals", "StyleValue"),),
    })

# CalculatedOr<Self, T> and PercentageOr<T> are C++ template mixins. V uses
# concrete tagged records for every instantiated value family, so require each
# concrete operation to remain present when reconciling the shared template
# bodies and map the per-family C++ out-of-line methods to their exact V path.
_CALCULATED_OR_OWNERS = (
    "AngleOrCalculated", "FlexOrCalculated", "FrequencyOrCalculated",
    "IntegerOrCalculated", "LengthOrCalculated", "LengthOrAutoOrCalculated",
    "NumberOrCalculated", "PercentageOrCalculated", "ResolutionOrCalculated",
    "TimeOrCalculated",
)
for _method_name in (
    "is_calculated", "value", "as_style_value", "calculated", "resolved",
    "serialize", "to_string",
):
    CONSOLIDATED_METHOD_MAPPINGS[("CalculatedOr", _method_name)] = tuple(
        (_method_name, _owner_name) for _owner_name in _CALCULATED_OR_OWNERS
    )
CONSOLIDATED_METHOD_MAPPINGS[("CalculatedOr", "resolve_calculated")] = tuple(
    ("resolved", _owner_name) for _owner_name in _CALCULATED_OR_OWNERS
)
CONSOLIDATED_METHOD_MAPPINGS[("CalculatedOr", "create_style_value")] = tuple(
    ("as_style_value", _owner_name) for _owner_name in _CALCULATED_OR_OWNERS
)

_CALCULATED_OR_RESOLVERS = {
    "AngleOrCalculated": "resolve_angle",
    "FlexOrCalculated": "resolve_flex",
    "FrequencyOrCalculated": "resolve_frequency",
    "IntegerOrCalculated": "resolve_integer",
    "LengthOrCalculated": "resolve_length",
    "LengthOrAutoOrCalculated": "resolve_length",
    "NumberOrCalculated": "resolve_number",
    "PercentageOrCalculated": "resolve_percentage",
    "ResolutionOrCalculated": "resolve_resolution",
    "TimeOrCalculated": "resolve_time",
}
for _owner_name, _resolver_name in _CALCULATED_OR_RESOLVERS.items():
    CONSOLIDATED_METHOD_MAPPINGS[(_owner_name, "resolve_calculated")] = (
        (_resolver_name, "CalculatedStyleValue"),
    )
    CONSOLIDATED_METHOD_MAPPINGS[(_owner_name, "create_style_value")] = (
        ("as_style_value", _owner_name),
    )

_PERCENTAGE_OR_OWNERS = (
    "AnglePercentage", "FrequencyPercentage", "LengthPercentage",
    "TimePercentage", "NumberPercentage",
)
for _method_name in (
    "is_percentage", "is_calculated", "contains_percentage", "percentage",
    "calculated", "resolved", "serialize", "to_string",
):
    CONSOLIDATED_METHOD_MAPPINGS[("PercentageOr", _method_name)] = tuple(
        (_method_name, _owner_name) for _owner_name in _PERCENTAGE_OR_OWNERS
    )
CONSOLIDATED_METHOD_MAPPINGS.update({
    ("PercentageOr", "to_px"): (("to_px", "LengthPercentage"),),
    ("PercentageOr", "is_t"): (
        ("is_angle", "AnglePercentage"),
        ("is_frequency", "FrequencyPercentage"),
        ("is_length", "LengthPercentage"),
        ("is_time", "TimePercentage"),
        ("is_number", "NumberPercentage"),
    ),
    ("PercentageOr", "get_t"): (
        ("angle", "AnglePercentage"),
        ("frequency", "FrequencyPercentage"),
        ("length", "LengthPercentage"),
        ("time", "TimePercentage"),
        ("number", "NumberPercentage"),
    ),
    ("ColumnCount", "make_auto"): (("column_count", "InitialValues"),),
    ("ColumnCount", "make_integer"): (("set_column_count", "MutableComputedValues"),),
    ("ColumnCount", "is_auto"): (("column_count", "ComputedValues"),),
    ("ColumnCount", "value"): (("column_count", "ComputedValues"),),
    ("BooleanNotExpression", "create"): (("create_not", "BooleanExpression"),),
    ("BooleanExpressionInParens", "create"): (
        ("create_in_parens", "BooleanExpression"),
    ),
    ("BooleanAndExpression", "create"): (("create_and", "BooleanExpression"),),
    ("BooleanOrExpression", "create"): (("create_or", "BooleanExpression"),),
    ("ConstantBooleanExpression", "create"): (
        ("create_constant", "BooleanExpression"),
    ),
    ("StyleValue", "as_abstract_image"): (
        ("style_value_from_css_image_source_for_value_logic", None),
    ),
})

# The base Box hook is invoked while V lowers committed UsedValues into a
# BlockBox. ImageProvider's C++ base class is split between ImageBox's retained
# relayout state and the concrete HTML image/object provider models.
CONSOLIDATED_METHOD_MAPPINGS.update({
    ("Box", "did_set_content_size"): (
        ("block_box_from_typed_layout_with_ancestor", None),
    ),
    ("ImageProvider", "did_update_alt_text"): (
        ("dom_node_did_update_alt_text", "ImageBox"),
    ),
    ("ImageProvider", "intrinsic_size"): (("available_html_image_natural_size", None),),
    ("ImageProvider", "current_image_bitmap"): (
        ("html_image_element_current_image_bitmap_sized", None),
    ),
    ("ImageProvider", "default_image_bitmap"): (
        ("html_image_element_default_image_bitmap_sized", None),
    ),
    ("ImageProvider", "default_image_bitmap_sized"): (
        ("html_image_element_default_image_bitmap_sized", None),
    ),
    ("ImageProvider", "image_provider_visit_edges"): (
        ("block_box_from_typed_layout_with_ancestor", None),
    ),
    ("GeneralEnclosed", "create"): (
        ("create_general_enclosed", "BooleanExpression"),
    ),
})

# Media features and @supports leaves are separate BooleanExpression subclasses
# in C++. V retains their discriminator, operands, serialized text, and match
# result on one tagged BooleanExpression record. Parsing constructs that record
# directly, and the shared methods dispatch on its kind.
CONSOLIDATED_METHOD_MAPPINGS.update({
    ("MediaFeatureValue", "to_string"): (
        ("serialize", "StyleValue"),
        ("supports_component_values_to_string", None),
    ),
    ("MediaFeatureValue", "is_same_type"): (
        ("compare_media_feature_values", None),
    ),
    ("MediaFeature", "to_string"): (("to_string", "BooleanExpression"),),
    ("MediaFeature", "evaluate"): (("evaluate_media_feature", None),),
    ("MediaFeature", "compare"): (("compare_media_feature_values", None),),
    ("MediaFeature", "dump"): (("dump", "BooleanExpression"),),
    ("MediaFeature", "boolean"): (("create_media_feature", "BooleanExpression"),),
    ("MediaFeature", "plain"): (("create_media_feature", "BooleanExpression"),),
    ("MediaFeature", "min"): (("create_media_feature", "BooleanExpression"),),
    ("MediaFeature", "max"): (("create_media_feature", "BooleanExpression"),),
    ("MediaFeature", "half_range"): (("create_media_feature", "BooleanExpression"),),
    ("MediaFeature", "range"): (("create_media_feature", "BooleanExpression"),),
    ("PseudoElementSelector", "is_known_pseudo_element_type"): (
        ("is_known_pseudo_element_type", None),
    ),
    ("Declaration", "create"): (
        ("create_supports_declaration", "BooleanExpression"),
    ),
    ("Declaration", "evaluate"): (("evaluate", "BooleanExpression"),),
    ("Declaration", "to_string"): (("to_string", "BooleanExpression"),),
    ("Declaration", "dump"): (("dump", "BooleanExpression"),),
    ("Selector", "evaluate"): (("evaluate", "BooleanExpression"),),
    ("Selector", "to_string"): (("to_string", "BooleanExpression"),),
    ("Selector", "dump"): (("dump", "BooleanExpression"),),
    ("FontTech", "create"): (("create_supports_font_tech", "BooleanExpression"),),
    ("FontTech", "evaluate"): (("evaluate", "BooleanExpression"),),
    ("FontTech", "dump"): (("dump", "BooleanExpression"),),
    ("FontFormat", "create"): (
        ("create_supports_font_format", "BooleanExpression"),
    ),
    ("FontFormat", "evaluate"): (("evaluate", "BooleanExpression"),),
    ("FontFormat", "to_string"): (("to_string", "BooleanExpression"),),
    ("FontFormat", "dump"): (("dump", "BooleanExpression"),),
    ("Supports", "matches"): (("matches_condition", "Supports"),),
    # The audit flattens Supports::Selector and CSS::Selector to the same owner
    # key. Require both active constructors so either C++ create() body remains
    # covered by the pair of concrete V selector representations.
    ("Selector", "create"): (
        ("create_selector", None),
        ("create_supports_selector", "BooleanExpression"),
    ),
})

# Parser::TokenStream's RAII StateTransaction becomes the explicit mark stack
# on ParserTokenStream. The selector parser is decomposed around textual spans,
# but preserves the same complex/compound/simple, qualified-name, pseudo, An+B,
# and page-selector algorithms.
CONSOLIDATED_METHOD_MAPPINGS.update({
    ("StateTransaction", "create_child"): (("mark", "ParserTokenStream"),),
    ("StateTransaction", "commit"): (("discard_a_mark", "ParserTokenStream"),),
    ("TokenStream", "of_single_token"): (("from_values", "ParserTokenStream"),),
    ("TokenStream", "current_token"): (("peek_token", "ParserTokenStream"),),
    ("TokenStream", "begin_transaction"): (("mark", "ParserTokenStream"),),
    ("TokenStream", "dump_all_tokens"): (("dump_string", "ParserTokenStream"),),
    ("TokenStream", "make_eof"): (("create_eof_token", "Tokenizer"),),
    ("Parser", "parse_as_pseudo_element_selector"): (("parse_pseudo_selector", None),),
    ("Parser", "parse_complex_selector"): (("parse_complex_selector", None),),
    ("Parser", "parse_compound_selector"): (("parse_complex_selector", None),),
    ("Parser", "parse_selector_combinator"): (("parse_complex_selector", None),),
    ("Parser", "parse_selector_qualified_name"): (
        ("parse_type_or_universal_selector", None),
        ("parse_attribute_selector", None),
    ),
    ("Parser", "parse_attribute_simple_selector"): (("parse_attribute_selector", None),),
    ("Parser", "parse_pseudo_simple_selector"): (("parse_pseudo_selector", None),),
    ("Parser", "parse_simple_selector"): (("parse_simple_selector", None),),
    ("Parser", "parse_a_n_plus_b_pattern"): (("parse_an_plus_b", None),),
    ("Parser", "parse_as_page_selector_list"): (("parse_page_selector_list", None),),
    ("Parser", "parse_a_page_selector_list"): (
        ("parse_a_page_selector_list_translated", None),
    ),
})

# The six C++ SyntaxNode subclasses are one tagged SyntaxNode in V.
CONSOLIDATED_METHOD_MAPPINGS.update({
    ("UniversalSyntaxNode", "create"): (("create_universal", "SyntaxNode"),),
    ("IdentSyntaxNode", "create"): (("create_ident", "SyntaxNode"),),
    ("IdentSyntaxNode", "ident"): (("ident", "SyntaxNode"),),
    ("TypeSyntaxNode", "type_name"): (("type_name", "SyntaxNode"),),
    ("MultiplierSyntaxNode", "create"): (("create_multiplier", "SyntaxNode"),),
    ("MultiplierSyntaxNode", "child"): (("child", "SyntaxNode"),),
    ("CommaSeparatedMultiplierSyntaxNode", "create"): (
        ("create_comma_separated_multiplier", "SyntaxNode"),
    ),
    ("CommaSeparatedMultiplierSyntaxNode", "child"): (("child", "SyntaxNode"),),
    ("AlternativesSyntaxNode", "create"): (("create_alternatives", "SyntaxNode"),),
})

# V's tagged ParsingError union has one exhaustive, length-delimited key
# function in place of eleven identical per-record Traits::hash bodies.
for _parsing_error_owner in (
    "UnknownPropertyError", "UnknownRuleError", "UnknownMediaFeatureError",
    "UnknownPseudoClassOrElementError", "InvalidPropertyError",
    "InvalidValueError", "InvalidRuleError", "InvalidQueryError",
    "InvalidSelectorError", "InvalidPseudoClassOrElementError",
    "InvalidRuleLocationError",
):
    CONSOLIDATED_METHOD_MAPPINGS[(_parsing_error_owner, "hash")] = (
        ("parsing_error_key", None),
    )

# The remaining syntax-node implementation bodies dispatch through the same
# tagged SyntaxNode used by the parser and header factories above.
for _syntax_owner in (
    "UniversalSyntaxNode", "TypeSyntaxNode", "IdentSyntaxNode",
    "MultiplierSyntaxNode", "CommaSeparatedMultiplierSyntaxNode",
    "AlternativesSyntaxNode",
):
    CONSOLIDATED_METHOD_MAPPINGS[(_syntax_owner, "to_string")] = (
        ("to_string", "SyntaxNode"),
    )
    CONSOLIDATED_METHOD_MAPPINGS[(_syntax_owner, "dump")] = (
        ("dump", "SyntaxNode"),
    )
CONSOLIDATED_METHOD_MAPPINGS[("TypeSyntaxNode", "create")] = (
    ("create_type", "SyntaxNode"),
)

# Parser is split by responsibility in V: RuleSelectorParser owns CSS Syntax
# and rule/declaration conversion, while Parser owns typed value parsing. The
# wrapper methods which convert a parsed StyleValue into one of C++'s small
# Variant aliases disappear because the V callers retain the StyleValue sum.
CONSOLIDATED_METHOD_MAPPINGS.update({
    ("Parser", "parse_declaration_value"): (("parse_declaration_value", None),),
    ("Parser", "parse_angle_percentage"): (("parse_angle_percentage_value", "Parser"),),
    ("Parser", "parse_flex"): (("parse_flex_value", "Parser"),),
    ("Parser", "parse_frequency"): (("parse_frequency_value", "Parser"),),
    ("Parser", "parse_frequency_percentage"): (
        ("parse_frequency_percentage_value", "Parser"),
    ),
    ("Parser", "parse_integer"): (("parse_integer_value", "Parser"),),
    ("Parser", "parse_length_percentage"): (("parse_length_percentage_value", "Parser"),),
    ("Parser", "parse_number_percentage"): (("parse_number_percentage_value", "Parser"),),
    ("Parser", "parse_resolution"): (("parse_resolution_value", "Parser"),),
    ("Parser", "parse_time"): (("parse_time_value", "Parser"),),
    ("Parser", "parse_time_percentage"): (("parse_time_percentage_value", "Parser"),),
    ("Parser", "parse_lab_color_value"): (("parse_lab_like_color_value", "Parser"),),
    ("Parser", "parse_oklab_color_value"): (("parse_lab_like_color_value", "Parser"),),
    ("Parser", "parse_lch_color_value"): (("parse_lch_like_color_value", "Parser"),),
    ("Parser", "parse_oklch_color_value"): (("parse_lch_like_color_value", "Parser"),),
    ("Parser", "parse_symbol_value"): (("parse_symbol_value", None),),
    ("Parser", "parse_nonnegative_integer_symbol_pair_value"): (
        ("parse_nonnegative_integer_symbol_pair_value", None),
    ),
    ("Parser", "parse_url_function"): (("parse_url_function", None),),
    ("Parser", "parse_grid_minmax"): (("parse_grid_minmax_kinds", "Parser"),),
    ("Parser", "parse_calculated_value"): (("parse_calculated_value", None),),
    ("Parser", "parse_a_calc_function_node"): (("parse_calc_function_node", "Parser"),),
    ("Parser", "convert_to_calculation_node"): (("parse_a_calculation", "Parser"),),
    ("Parser", "resolve_unresolved_style_value"): (
        ("resolve_unresolved_style_value_for_property_with_context", None),
    ),
    ("Parser", "consume_a_simple_block_and_do_nothing"): (
        ("parser_consume_a_simple_block", None),
    ),
    ("Parser", "consume_a_function_and_do_nothing"): (
        ("parser_consume_a_function", None),
    ),
    ("Parser", "parse_a_blocks_contents"): (
        ("consume_a_blocks_contents", "RuleSelectorParser"),
    ),
    ("Parser", "parse_as_supports_condition"): (
        ("parse_supports_declaration_from_parser_tokens", None),
    ),
    ("Parser", "parse_as_property_declaration_block"): (
        ("parse_css_property_declaration_block_with_params", None),
    ),
    ("Parser", "parse_as_descriptor_declaration_block"): (
        ("parse_css_descriptor_declaration_block", None),
    ),
    ("Parser", "is_valid_in_the_current_context"): (
        ("is_valid_declaration_in_the_current_context", "RuleSelectorParser"),
        ("is_valid_at_rule_in_the_current_context", "RuleSelectorParser"),
        ("is_valid_qualified_rule_in_the_current_context", "RuleSelectorParser"),
    ),
    ("Parser", "extract_property"): (("convert_to_style_declaration", "RuleSelectorParser"),),
    ("Parser", "convert_to_style_property"): (
        ("convert_to_style_declaration", "RuleSelectorParser"),
    ),
    ("Parser", "parse_as_css_value"): (("parse_css_value_for_property", "Parser"),),
    ("Parser", "parse_as_descriptor_value"): (("parse_descriptor_value", "Parser"),),
    ("Parser", "parse_according_to_syntax_node"): (
        ("parse_according_to_syntax_node", None),
    ),
    ("Parser", "parse_with_a_syntax"): (("parse_with_a_syntax", None),),
})

# Rule subclasses become one CSSRule record in V. Their accessors either use a
# shared operation or expose the field belonging to that discriminator. Typed
# indexed-property conversion similarly becomes an identity conversion because
# the V API already accepts the narrowed sum type instead of a raw JS value.
CONSOLIDATED_METHOD_MAPPINGS.update({
    ("CSSFontFeatureValuesMap", "map_entries"): (
        ("to_ordered_hash_map", "CSSFontFeatureValuesMap"),
    ),
    ("CSSGroupingRule", "css_rules_for_bindings"): (("css_rules", "CSSRule"),),
    ("CSSKeyframesRule", "set_name"): (("set_keyframes_name", "CSSRule"),),
    ("CSSMediaRule", "evaluate"): (("evaluate_media", "CSSRule"),),
    ("CSSStyleSheet", "construct_impl"): (("css_style_sheet_construct", None),),
    ("Subresource", "set_loading_state"): (("set_loading_state", "CSSRule"),),
    ("CSSTransformComponent", "set_is_2d"): (
        ("set_is_2d", "CSSMatrixComponent"),
        ("set_is_2d", "CSSPerspective"),
        ("set_is_2d", "CSSRotate"),
        ("set_is_2d", "CSSScale"),
        ("set_is_2d", "CSSSkew"),
        ("set_is_2d", "CSSSkewX"),
        ("set_is_2d", "CSSSkewY"),
        ("set_is_2d", "CSSTranslate"),
    ),
    ("MediaList", "item_value"): (("item", "MediaList"),),
    ("ParsedFontFace", "parent_rule"): (("parent_rule_ref", "ParsedFontFace"),),
    ("PropertyNameAndID", "to_string"): (("name", "PropertyNameAndID"),),
    ("TouchActionData", "none"): (("none_", "TouchActionData"),),
    # MutableComputedValues stores content in C++; V computes the same typed
    # content data directly from the retained property map when Layout asks.
    ("MutableComputedValues", "set_content"): (("content", "ComputedProperties"),),
    # Font stylesheet ownership and the JS promise wrapper are decomposed from
    # the same font loading algorithms in the typed V model.
    ("FontComputer", "load_fonts_from_sheet"): (("load_fonts_from_css_rules", "FontComputer"),),
    ("FontComputer", "unload_fonts_from_sheet"): (("unload_fonts_from_css_rules", "FontComputer"),),
    ("FontFace", "font_status_promise"): (("font_status_promise_ref", "FontFaceObject"),),
    # C++ hash traits become the exact serialized keys consumed by V maps.
    ("FontWeightRange", "hash"): (("id", "FontWeightRange"),),
    ("OwnFontFaceKey", "hash"): (("id", "OwnFontFaceKey"),),
    ("HasResultCacheKeyTraits", "hash"): (("has_result_cache_key", None),),
    # Callback iteration over NumericType's sparse exponents is represented by
    # enumerating the base types and reading each optional exponent.
    ("NumericType", "for_each_type_and_exponent"): (
        ("numeric_base_types", None),
        ("exponent", "NumericType"),
    ),
    # Parser's generic callback form and vendor-prefix predicate have concrete
    # specialized equivalents at the active property parser boundary.
    ("Parser", "parse_comma_separated_value_list"): (
        ("parse_simple_comma_separated_value_list", "Parser"),
    ),
    ("Parser", "has_ignored_vendor_prefix"): (("has_ignored_vendor_prefix_local", None),),
    # C++ keeps the radius/filter operations on differently named nested
    # classes; V gives those value records unambiguous owners.
    ("BorderRadiusStyleValue", "horizontal_radius"): (("horizontal_radius_", "BorderRadiusStyleValue"),),
    ("BorderRadiusStyleValue", "vertical_radius"): (("vertical_radius_", "BorderRadiusStyleValue"),),
    ("Blur", "resolved_radius"): (("resolved_radius", "FilterOperationBlur"),),
    ("HueRotate", "angle_degrees"): (("angle_degrees", "FilterOperationHueRotate"),),
    ("Color", "resolved_amount"): (("resolved_amount", "FilterOperationColor"),),
    ("PendingSubstitutionStyleValue", "original_shorthand_value"): (
        ("original_shorthand_value_ref", "PendingSubstitutionStyleValue"),
    ),
    # Abstract image Typed-OM reification constructs the V image wrapper.
    ("AbstractImageStyleValue", "reify"): (("create", "CSSImageValue"),),
    ("ColorFunctionStyleValue", "is_color_function"): (("is_color_function", "StyleValue"),),
    ("ColorResolutionContext", "for_layout_node_with_style"): (
        ("color_resolution_context_for_layout_node", None),
    ),
    # Gradient image resolution lives at the Layout boundary because only
    # Layout knows the concrete tile size. The resulting typed command is
    # submitted through the corresponding renderer-independent recorder call.
    ("LinearGradientStyleValue", "resolve_for_size"): (("resolve_linear_gradient_data", None),),
    ("LinearGradientStyleValue", "paint"): (
        ("resolve_background_gradient", None),
        ("fill_rect_with_linear_gradient", "DisplayListRecorder"),
    ),
    ("RadialGradientStyleValue", "resolve_size"): (("radial_extent_size", None),),
    ("RadialGradientStyleValue", "resolve_for_size"): (("resolve_radial_gradient_data", None),),
    ("RadialGradientStyleValue", "paint"): (
        ("resolve_background_gradient", None),
        ("fill_rect_with_radial_gradient", "DisplayListRecorder"),
    ),
    ("ConicGradientStyleValue", "resolve_for_size"): (("resolve_conic_gradient_data", None),),
    ("ConicGradientStyleValue", "paint"): (
        ("resolve_background_gradient", None),
        ("fill_rect_with_conic_gradient", "DisplayListRecorder"),
    ),
    # CSS ImageStyleValue painting is consumed by the retained image paintable;
    # decoded bitmap geometry/scaling is performed by this active paint method.
    ("ImageStyleValue", "paint"): (("paint", "ImagePaintable"),),
    # The C++ CRTP helper forwards equality to each value's properties_equal;
    # V's exhaustive StyleValue equality is the corresponding sum dispatch.
    ("StyleValueWithDefaultOperators", "equals"): (("equals", "StyleValue"),),
})

# C++'s per-subclass virtual equality bodies become V's exhaustive StyleValue
# sum equality. Keep this list explicit so new upstream equality algorithms do
# not acquire coverage merely because they happen to share the method name.
for _style_value_equality_owner, _style_value_equality_name in (
    ("AngleStyleValue", "equals"),
    ("ColorFunctionStyleValue", "equals"),
    ("ColorInterpolationMethodStyleValue", "properties_equal"),
    ("ColorMixStyleValue", "equals"),
    ("ColorSchemeStyleValue", "properties_equal"),
    ("CustomIdentStyleValue", "properties_equal"),
    ("FitContentStyleValue", "equals"),
    ("FlexStyleValue", "equals"),
    ("FontStyleStyleValue", "equals"),
    ("FrequencyStyleValue", "equals"),
    ("GuaranteedInvalidStyleValue", "properties_equal"),
    ("HSLColorStyleValue", "equals"),
    ("HWBColorStyleValue", "equals"),
    ("IntegerStyleValue", "equals"),
    ("LCHLikeColorStyleValue", "equals"),
    ("LabLikeColorStyleValue", "equals"),
    ("LengthStyleValue", "equals"),
    ("LightDarkStyleValue", "equals"),
    ("LinearGradientStyleValue", "equals"),
    ("NumberStyleValue", "equals"),
    ("PendingSubstitutionStyleValue", "properties_equal"),
    ("PercentageStyleValue", "equals"),
    ("RGBColorStyleValue", "equals"),
    ("RadialGradientStyleValue", "equals"),
    ("RatioStyleValue", "properties_equal"),
    ("ResolutionStyleValue", "equals"),
    ("TimeStyleValue", "equals"),
    ("ConicGradientStyleValue", "equals"),
    ("StringStyleValue", "properties_equal"),
    ("TreeCountingFunctionStyleValue", "equals"),
    ("URLStyleValue", "properties_equal"),
):
    CONSOLIDATED_METHOD_MAPPINGS[(_style_value_equality_owner, _style_value_equality_name)] = (
        ("equals", "StyleValue"),
    )

# BasicShape's C++ nested variant classes are standalone tagged records in V.
# Path construction is dispatched by BasicShapeStyleValue; the expensive shape
# geometry remains split into the concrete helpers named below.
CONSOLIDATED_METHOD_MAPPINGS.update({
    ("Inset", "to_path"): (("style_values_extra_inset_to_path", None),),
    ("Inset", "serialize"): (("serialize", "BasicShapeInset"),),
    ("Xywh", "serialize"): (("serialize", "BasicShapeXywh"),),
    ("Rect", "serialize"): (("serialize", "BasicShapeRect"),),
    ("Circle", "to_path"): (("style_values_extra_circle_to_path", None),),
    ("Circle", "serialize"): (("serialize", "BasicShapeCircle"),),
    ("Ellipse", "to_path"): (("style_values_extra_ellipse_to_path", None),),
    ("Ellipse", "serialize"): (("serialize", "BasicShapeEllipse"),),
    ("Polygon", "to_path"): (("style_values_extra_polygon_to_path", None),),
    ("Polygon", "serialize"): (("serialize", "BasicShapePolygon"),),
    ("Path", "to_path"): (("to_path", "BasicShapeStyleValue"),),
})

# CSSOM computed-value conversion and the Typed OM mutable property map share
# their translated algorithms with style_declarations.v rather than mirroring
# the C++ class/file boundary.
CONSOLIDATED_METHOD_MAPPINGS.update({
    ("CSSStyleProperties", "convert_declarations_to_specified_order"): (
        ("convert_declarations_to_specified_order", None),
    ),
    ("StylePropertyMap", "create"): (("create", "MutableStylePropertyMap"),),
    ("StylePropertyMap", "set"): (("set", "MutableStylePropertyMap"),),
    ("StylePropertyMap", "append"): (("append", "MutableStylePropertyMap"),),
    ("StylePropertyMap", "delete_"): (("delete_", "MutableStylePropertyMap"),),
    ("StylePropertyMap", "clear"): (("clear", "MutableStylePropertyMap"),),
})

# AbstractImageStyleValue virtual defaults are encoded by CSSImageSource's sum
# type dispatch. Concrete URLs retain intrinsic metadata and resource loading;
# gradients resolve only after Layout supplies their final tile size.
CONSOLIDATED_METHOD_MAPPINGS.update({
    ("Element", "apply_presentational_hints"): (
        ("collect_element_presentational_hints", None),
    ),
    ("AbstractImageStyleValue", "natural_width"): (
        ("style_values_extra_image_natural_size", None),
    ),
    ("AbstractImageStyleValue", "natural_height"): (
        ("style_values_extra_image_natural_size", None),
    ),
    ("AbstractImageStyleValue", "natural_aspect_ratio"): (
        ("style_values_extra_image_natural_size", None),
    ),
    ("AbstractImageStyleValue", "load_any_resources"): (
        ("load_any_resources", "ImageStyleValue"),
    ),
    ("AbstractImageStyleValue", "resolve_for_size"): (
        ("resolve_background_gradient", None),
    ),
    ("AbstractImageStyleValue", "color_if_single_pixel_bitmap"): (
        ("color_if_single_pixel_bitmap", "ImageStyleValue"),
    ),
})

# Color component resolution/serialization is shared by every concrete V color
# record. The C++ base member bodies therefore map to these module-private
# helpers, while has_color() dispatches over the StyleValue sum type.
CONSOLIDATED_METHOD_MAPPINGS.update({
    ("ColorStyleValue", "resolve_hue"): (("resolve_hue", None),),
    ("ColorStyleValue", "resolve_with_reference_value"): (
        ("resolve_with_reference_value", None),
    ),
    ("ColorStyleValue", "resolve_alpha"): (("resolve_alpha", None),),
    ("ColorStyleValue", "serialize_color_component"): (
        ("serialize_color_component", None),
    ),
    ("ColorStyleValue", "serialize_alpha_component"): (
        ("serialize_alpha_component", None),
    ),
    ("ColorStyleValue", "serialize_hue_component"): (
        ("serialize_hue_component", None),
    ),
    ("ColorStyleValue", "has_color"): (("has_color", "StyleValue"),),
})

# C++ exposes a temporary view which lowers Rust FFI filter records. V's
# ComputedProperties already owns the materialized Filter and its typed
# operations; URL fragment validation happens at the SVG paint resolver.
CONSOLIDATED_METHOD_MAPPINGS.update({
    ("ComputedFilterView", "has_filters"): (("has_filters", "Filter"),),
    ("ComputedFilterView", "is_none"): (("is_none", "Filter"),),
    ("ComputedFilterView", "for_each_operation"): (("filters", "Filter"),),
    ("ComputedFilterView", "url_fragment"): (("resolved_svg_filter", None),),
    ("ComputedFilterView", "materialize"): (
        ("new", "Filter"),
        ("filters", "Filter"),
    ),
})

# Length contexts are CSS-owned in V; Layout supplies its retained computed
# metrics through dom.LayoutNode without introducing a CSS -> Layout cycle.
CONSOLIDATED_METHOD_MAPPINGS.update({
    ("ResolutionContext", "for_element"): (("for_element", "LengthResolutionContext"),),
    ("ResolutionContext", "for_window"): (("for_window", "LengthResolutionContext"),),
    ("ResolutionContext", "for_document"): (("for_document", "LengthResolutionContext"),),
    ("ResolutionContext", "for_layout_node"): (
        ("for_layout_node", "LengthResolutionContext"),
    ),
    ("ResolutionContext", "set_did_resolve_viewport_relative_length"): (
        ("set_did_resolve_viewport_relative_length", "LengthResolutionContext"),
    ),
    ("ResolutionContext", "viewport_metric_dependency_flag"): (
        ("viewport_metric_dependency_flag", "LengthResolutionContext"),
    ),
    ("ResolutionContext", "record_viewport_relative_length_resolution"): (
        ("record_viewport_relative_length_resolution", "LengthResolutionContext"),
    ),
    ("ResolutionContext", "record_font_relative_length_resolution"): (
        ("record_font_relative_length_resolution", "LengthResolutionContext"),
    ),
    ("Length", "to_px_slow_case"): (("to_px_slow_case_for_layout_node", "Length"),),
    ("CountingBloomFilter", "bucket1"): (("hash1", "CountingBloomFilter"),),
    ("CountingBloomFilter", "bucket2"): (("hash2", "CountingBloomFilter"),),
})

# StyleScope's four process-wide UA sheets are selected by one cached lookup in
# V, and its nullable cache accessors make validity explicit to callers.
CONSOLIDATED_METHOD_MAPPINGS.update({
    ("StyleScope", "node"): (("node_ref", "StyleScope"),),
    ("StyleScope", "author_rule_cache"): (("author_rule_caches", "StyleScope"),),
    ("StyleScope", "user_rule_cache"): (("user_rule_caches", "StyleScope"),),
    ("StyleScope", "user_agent_rule_cache"): (
        ("user_agent_rule_caches", "StyleScope"),
    ),
})

# EasingStyleValue's nested C++ Function variant is an explicit V sum type.
CONSOLIDATED_METHOD_MAPPINGS.update({
    ("Linear", "serialize"): (("serialize", "EasingLinear"),),
    ("Linear", "to_string"): (("serialize", "EasingLinear"),),
    ("CubicBezier", "serialize"): (("serialize", "EasingCubicBezier"),),
    ("CubicBezier", "to_string"): (("serialize", "EasingCubicBezier"),),
    ("Steps", "serialize"): (("serialize", "EasingSteps"),),
    ("Steps", "to_string"): (("serialize", "EasingSteps"),),
    ("Function", "serialize"): (("serialize", "EasingStyleValueFunction"),),
})

# DisplayListPlayerSkia is the native raster backend in C++. The standalone V
# package ends at renderer-independent commands and a deterministic playback
# plan; concrete draw operations are recorded by DisplayListRecorder and
# backend context changes are represented by PlaybackPlanner actions.
for _method_name in ("execute", "execute_display_list_into_surface", "execute_impl", "surface"):
    CONSOLIDATED_METHOD_MAPPINGS[("DisplayListPlayer", _method_name)] = (
        ("playback_plan", "DisplayList"),
    )
CONSOLIDATED_METHOD_MAPPINGS[("DisplayList", "create")] = (
    ("new_display_list_recorder", None),
)
CONSOLIDATED_METHOD_MAPPINGS[("ExternalContentSource", "create")] = (
    ("update", "ExternalContentSource"),
)

for _method_name in (
    "draw_glyph_run", "fill_rect", "draw_external_content",
    "draw_scaled_immutable_bitmap", "draw_repeated_immutable_bitmap",
    "add_clip_rect", "save", "save_layer", "restore", "translate",
    "paint_outer_box_shadow", "paint_inner_box_shadow", "paint_text_shadow",
    "fill_rect_with_rounded_corners", "fill_path", "stroke_path",
    "draw_ellipse", "fill_ellipse", "draw_line", "apply_backdrop_filter",
    "draw_rect", "add_rounded_rect_clip", "paint_nested_display_list",
    "paint_scrollbar", "apply_effects",
):
    CONSOLIDATED_METHOD_MAPPINGS[("DisplayListPlayerSkia", _method_name)] = (
        (_method_name, "DisplayListRecorder"),
    )

CONSOLIDATED_METHOD_MAPPINGS.update({
    ("DisplayListPlayerSkia", "flush"): (("playback_plan", "DisplayList"),),
    ("DisplayListPlayerSkia", "paint_linear_gradient"): (
        ("fill_rect_with_linear_gradient", "DisplayListRecorder"),
    ),
    ("DisplayListPlayerSkia", "paint_style_to_skia_paint"): (
        ("expand_color_stops_for_painting", None),
    ),
    ("DisplayListPlayerSkia", "paint_radial_gradient"): (
        ("fill_rect_with_radial_gradient", "DisplayListRecorder"),
    ),
    ("DisplayListPlayerSkia", "paint_conic_gradient"): (
        ("fill_rect_with_conic_gradient", "DisplayListRecorder"),
    ),
    ("DisplayListPlayerSkia", "apply_transform"): (("apply_context", "PlaybackPlanner"),),
    ("DisplayListPlayerSkia", "add_clip_path"): (("apply_context", "PlaybackPlanner"),),
    ("DisplayListPlayerSkia", "would_be_fully_clipped_by_painter"): (
        ("playback_plan", "DisplayList"),
    ),
})

# Paintable/PaintableBox virtual dispatch is encoded by the retained Node kind,
# BlockBox paint plan, text fragments, and SVG resource collectors. Keep each
# mapping on the active bridge or renderer helper that consumes that state.
CONSOLIDATED_METHOD_MAPPINGS.update({
    ("Paintable", "set_dom_node"): (("materialize_dom_paintables", None),),
    ("Paintable", "handle_mousewheel"): (("handle_mousewheel", "PaintableBox"),),
    ("Paintable", "hit_test"): (("hit_test", "PaintableTree"),),
    ("Paintable", "enclosing_stacking_context"): (("parent", "StackingContext"),),
    ("Paintable", "is_absolutely_positioned"): (
        ("is_absolutely_positioned", "Node"),
    ),
    ("Paintable", "paint"): (("flat_paint_commands", "BlockBox"),),
    ("Paintable", "forms_unconnected_subtree"): (
        ("collect_svg_clip_path_components", None),
        ("collect_svg_mask_paint_operations", None),
        ("resolve_svg_pattern_paint_style", None),
    ),
    ("Paintable", "is_navigable_container_viewport_paintable"): (
        ("is_navigable_container_viewport", "Node"),
    ),
    ("Paintable", "is_viewport_paintable"): (("is_viewport", "Node"),),
    ("Paintable", "is_paintable_with_lines"): (("text_lines_from_typed_layout", None),),
    ("Paintable", "is_svg_paintable"): (("is_svg_box", "Node"),),
    ("Paintable", "is_svg_svg_paintable"): (("is_svg_svg_box", "Node"),),
    ("Paintable", "is_svg_path_paintable"): (("is_svg_geometry_box", "Node"),),
    ("Paintable", "is_svg_graphics_paintable"): (("is_svg_graphics_box", "Node"),),
    ("Paintable", "is_text_paintable"): (("is_text_node", "Node"),),
    ("Paintable", "paint_inspector_overlay_internal"): (
        ("compatibility_paint_box_inspector_overlay", None),
    ),
    ("PaintableBox", "create"): (
        ("block_box_from_typed_layout_with_ancestor", None),
    ),
    ("PaintableBox", "reset_for_relayout"): (
        ("block_box_from_typed_layout_with_ancestor", None),
    ),
    ("PaintableBox", "paint"): (("flat_paint_commands", "BlockBox"),),
    ("PaintableBox", "paint_border"): (("paint_all_borders", None),),
    ("PaintableBox", "resize_handle"): (
        ("paintable_box_absolute_resizer_rect", None),
    ),
    ("PaintableBox", "ensure_resize_handle"): (
        ("paintable_box_absolute_resizer_rect", None),
    ),
    ("PaintableBox", "hit_test"): (("viewport_hit_test", None),),
    ("PaintableBox", "hit_test_children"): (("viewport_hit_test", None),),
    ("PaintableBox", "get_mask_area"): (("svg_url_mask_for_box", None),),
    ("PaintableBox", "get_mask_type"): (("svg_url_mask_for_box", None),),
    ("PaintableBox", "calculate_mask"): (("svg_url_mask_for_box", None),),
    ("PaintableBox", "get_clip_area"): (("svg_url_clip_path_for_box", None),),
    ("PaintableBox", "calculate_clip"): (("svg_url_clip_path_for_box", None),),
    ("PaintableFragment", "paintable"): (("text_lines_from_typed_layout", None),),
    ("ComputedTransforms", "svg_to_device_pixels_transform"): (
        ("painting_affine_from_svg", None),
    ),
    ("ViewportPaintable", "handle_mousewheel"): (("handle_mousewheel", "EventHandler"),),
})

# MediaSourceExtensions keeps parser cursor ownership and thread callbacks at
# the synchronous V append boundary. The mappings below point at the concrete
# algorithms that consume the same state; they are checked like every other
# consolidated mapping and fail open if an implementation disappears.
CONSOLIDATED_METHOD_MAPPINGS.update({
    ("ISOBMFFByteStreamParser", "supports_codec"): (
        ("isobmff_track_codec_is_supported", None),
    ),
    ("ISOBMFFByteStreamParser", "skip_ignored_bytes"): (
        ("ignored_element_length", "ISOBMFFByteStreamParser"),
    ),
    ("ISOBMFFByteStreamParser", "parse_movie_fragment"): (
        ("parse_media_segment", "ISOBMFFByteStreamParser"),
    ),
    ("SourceBuffer", "create"): (
        ("create_internal_for_media_source", "SourceBuffer"),
    ),
    ("SourceBufferProcessor", "set_parser"): (
        ("set_webm_parser", "SourceBufferProcessor"),
        ("set_isobmff_parser", "SourceBufferProcessor"),
    ),
    ("SourceBufferProcessor", "set_duration_change_callback"): (
        ("on_first_initialization_segment_processed", "SourceBuffer"),
    ),
    ("SourceBufferProcessor", "set_first_initialization_segment_callback"): (
        ("on_first_initialization_segment_processed", "SourceBuffer"),
    ),
    ("SourceBufferProcessor", "set_append_error_callback"): (
        ("run_append_error_algorithm", "SourceBuffer"),
    ),
    ("SourceBufferProcessor", "set_coded_frame_processing_done_callback"): (
        ("update_ready_state_and_duration_after_coded_frame_processing", "SourceBuffer"),
    ),
    ("SourceBufferProcessor", "set_append_done_callback"): (
        ("finish_buffer_append", "SourceBuffer"),
    ),
    ("SourceBufferProcessor", "initialization_segment_received"): (
        ("run_segment_parser_loop", "SourceBufferProcessor"),
        ("on_first_initialization_segment_processed", "SourceBuffer"),
    ),
    ("SourceBufferProcessor", "drop_consumed_bytes_from_input_buffer"): (
        ("drop_input_prefix", "SourceBufferProcessor"),
    ),
    ("SourceBufferProcessor", "set_need_random_access_point_flag_on_all_track_buffers"): (
        ("set_need_random_access_point_on_all_track_buffers", "SourceBufferProcessor"),
    ),
    ("SourceBufferProcessor", "buffered_ranges"): (
        ("buffered_time_ranges", "SourceBufferProcessor"),
    ),
    ("TrackBuffer", "track_buffer_ranges"): (
        ("buffered_time_ranges", "TrackBufferDemuxer"),
    ),
    ("TrackBufferDemuxer", "track_buffer_ranges"): (
        ("buffered_time_ranges", "TrackBufferDemuxer"),
    ),
    ("TrackBufferDemuxer", "extend_run_bounds_for_frame"): (
        ("recalculate_bounds", "FrameRun"),
    ),
    ("TrackBufferDemuxer", "recalculate_run_bounds"): (
        ("recalculate_bounds", "FrameRun"),
    ),
    ("TrackBufferDemuxer", "codec_configuration_after_frame_prefix_while_locked"): (
        ("codec_configuration_after_frame_prefix", None),
    ),
    ("TrackBufferDemuxer", "note_cursor_jumped_while_locked"): (
        ("note_cursor_jumped", "TrackBufferDemuxer"),
    ),
    ("TrackBufferDemuxer", "verify_runs_are_ordered_around_index_while_locked"): (
        ("add_coded_frame", "TrackBufferDemuxer"),
    ),
    ("TrackBufferDemuxer", "split_run_while_locked"): (
        ("erase_frames_and_dependants", "TrackBufferDemuxer"),
    ),
    ("TrackBufferDemuxer", "erase_frames_and_dependants_while_locked"): (
        ("erase_frames_and_dependants", "TrackBufferDemuxer"),
    ),
    ("TrackBufferDemuxer", "remove_coded_frames_and_dependants_in_range_returning_presentation_timestamp_at"): (
        ("remove_coded_frames_and_dependants_in_range_returning_timestamp", "TrackBufferDemuxer"),
    ),
    ("TrackBufferDemuxer", "is_frame_evictable_while_locked"): (
        ("frame_is_evictable", "TrackBufferDemuxer"),
    ),
    ("TrackBufferDemuxer", "run_ends_at_last_appended_frame_while_locked"): (
        ("run_ends_at_last_appended_frame", "TrackBufferDemuxer"),
    ),
    ("TrackBufferDemuxer", "count_frame_duration_while_locked"): (
        ("add_coded_frame", "TrackBufferDemuxer"),
    ),
    ("TrackBufferDemuxer", "decrement_frames_with_maximum_duration_while_locked"): (
        ("recalculate_maximum_frame_duration", "TrackBufferDemuxer"),
    ),
    ("TrackBufferDemuxer", "find_run_to_play_from_while_locked"): (
        ("find_run_to_play_from", "TrackBufferDemuxer"),
    ),
    ("TrackBufferDemuxer", "codec_configuration_at_position_while_locked"): (
        ("codec_configuration_after_frame_prefix", None),
    ),
    ("TrackBufferDemuxer", "get_next_sample_for_track"): (
        ("next_frame", "TrackBufferDemuxer"),
    ),
    ("TrackBufferDemuxer", "move_cursor_to_presentation_time_while_locked"): (
        ("seek_to_most_recent_keyframe", "TrackBufferDemuxer"),
    ),
    ("TrackBufferDemuxer", "queue_scan_state_change_dispatch_while_locked"): (
        ("dispatch_scan_state_change", "TrackBufferDemuxer"),
    ),
    ("WebMByteStreamParser", "supports_codec"): (
        ("webm_track_codec_is_supported", None),
    ),
    ("WebMByteStreamParser", "skip_ignored_bytes"): (
        ("ignored_element_length", "WebMByteStreamParser"),
    ),
})

# Inline C++ accessors whose state is deliberately exposed as a typed public V
# record field. These mappings are accepted only while the named owner/field
# exists, just as function mappings fail open when their implementation moves.
CONSOLIDATED_FIELD_MAPPINGS: dict[
    tuple[str, str], tuple[tuple[str, str], ...]
] = {
    # UndoStep exposes these immutable values through inline C++ getters. V's
    # record makes the same values directly readable by the history runner.
    ("UndoStep", "editing_host"): (("editing_host", "UndoStep"),),
    ("UndoStep", "category"): (("category", "UndoStep"),),
    ("SVGLengthValue", "kind"): (("kind", "SvgLengthValue"),),
    ("SVGLengthValue", "value"): (("value", "SvgLengthValue"),),
    # WebAudio's C++ offset helpers expose GC member locations to generated
    # bindings. V's typed records access those members directly; requiring the
    # concrete field keeps this disposition tied to real translated state.
    ("BaseAudioContext", "destination_offset"): (("destination", "BaseAudioContext"),),
    ("BaseAudioContext", "control_message_queue"): (
        ("control_messages", "BaseAudioContext"),
    ),
    ("BaseAudioContext", "set_listener"): (("listener", "BaseAudioContext"),),
    ("AudioListener", "position_x_offset"): (("position_x", "AudioListener"),),
    ("AudioListener", "position_y_offset"): (("position_y", "AudioListener"),),
    ("AudioListener", "position_z_offset"): (("position_z", "AudioListener"),),
    ("AudioListener", "forward_x_offset"): (("forward_x", "AudioListener"),),
    ("AudioListener", "forward_y_offset"): (("forward_y", "AudioListener"),),
    ("AudioListener", "forward_z_offset"): (("forward_z", "AudioListener"),),
    ("AudioListener", "up_x_offset"): (("up_x", "AudioListener"),),
    ("AudioListener", "up_y_offset"): (("up_y", "AudioListener"),),
    ("AudioListener", "up_z_offset"): (("up_z", "AudioListener"),),
    ("ConstantSourceNode", "offset_offset"): (("offset", "ConstantSourceNode"),),
    ("DelayNode", "delay_time_offset"): (("delay_time", "DelayNode"),),
    ("DynamicsCompressorNode", "threshold_offset"): (
        ("threshold", "DynamicsCompressorNode"),
    ),
    ("DynamicsCompressorNode", "knee_offset"): (("knee", "DynamicsCompressorNode"),),
    ("DynamicsCompressorNode", "ratio_offset"): (("ratio", "DynamicsCompressorNode"),),
    ("DynamicsCompressorNode", "attack_offset"): (("attack", "DynamicsCompressorNode"),),
    ("DynamicsCompressorNode", "release_offset"): (("release", "DynamicsCompressorNode"),),
    ("GainNode", "gain_offset"): (("gain", "GainNode"),),
    ("MediaElementAudioSourceNode", "media_element_offset"): (
        ("media_element_id", "MediaElementAudioSourceNode"),
    ),
    ("OfflineAudioCompletionEvent", "rendered_buffer_offset"): (
        ("rendered_buffer", "OfflineAudioCompletionEvent"),
    ),
    ("OscillatorNode", "frequency_offset"): (("frequency", "OscillatorNode"),),
    ("OscillatorNode", "detune_offset"): (("detune", "OscillatorNode"),),
    ("PannerNode", "position_x_offset"): (("position_x", "PannerNode"),),
    ("PannerNode", "position_y_offset"): (("position_y", "PannerNode"),),
    ("PannerNode", "position_z_offset"): (("position_z", "PannerNode"),),
    ("PannerNode", "orientation_x_offset"): (("orientation_x", "PannerNode"),),
    ("PannerNode", "orientation_y_offset"): (("orientation_y", "PannerNode"),),
    ("PannerNode", "orientation_z_offset"): (("orientation_z", "PannerNode"),),
    ("StereoPannerNode", "pan_offset"): (("pan", "StereoPannerNode"),),
    # MediaFeature's C++ tagged union is flattened onto BooleanExpression, and
    # MediaFeatureValue's variant discriminator is explicit in its active local
    # value record. Each predicate remains a checked read of that discriminator.
    ("MediaFeatureValue", "is_ident"): (("kind", "MediaFeatureValueLocal"),),
    ("MediaFeatureValue", "is_length"): (("kind", "MediaFeatureValueLocal"),),
    ("MediaFeatureValue", "is_integer"): (("kind", "MediaFeatureValueLocal"),),
    ("MediaFeatureValue", "is_ratio"): (("kind", "MediaFeatureValueLocal"),),
    ("MediaFeatureValue", "is_resolution"): (("kind", "MediaFeatureValueLocal"),),
    ("MediaFeatureValue", "is_unknown"): (("kind", "MediaFeatureValueLocal"),),
    ("MediaFeature", "m_type"): (("media_feature_kind", "BooleanExpression"),),
    ("MediaFeature", "value"): (("media_feature_value", "BooleanExpression"),),
    # Selector variants are explicit fields rather than a nested C++ Variant.
    ("PseudoElementSelector", "m_type"): (("type_", "PseudoElementSelector"),),
    ("PseudoElementSelector", "type"): (("type_", "PseudoElementSelector"),),
    ("PseudoElementSelector", "pt_name_selector"): (
        ("pt_name_selector", "PseudoElementSelector"),
    ),
    ("PseudoElementSelector", "compound_selector"): (
        ("compound_selector", "PseudoElementSelector"),
    ),
    ("PseudoElementSelector", "ident_list"): (("ident_list", "PseudoElementSelector"),),
    ("SimpleSelector", "attribute"): (("attribute", "SimpleSelector"),),
    ("SimpleSelector", "pseudo_class"): (("pseudo_class", "SimpleSelector"),),
    ("SimpleSelector", "pseudo_element"): (("pseudo_element", "SimpleSelector"),),
    ("SimpleSelector", "name"): (("name", "SimpleSelector"),),
    ("SimpleSelector", "lowercase_name"): (("lowercase_name", "SelectorName"),),
    ("SimpleSelector", "qualified_name"): (("qualified_name", "SimpleSelector"),),
    ("TokenStream", "current_index"): (("index", "ParserTokenStream"),),
    ("TypeSyntaxNode", "value_type"): (("value_type", "SyntaxNode"),),
    ("AlternativesSyntaxNode", "children"): (("children", "SyntaxNode"),),
    ("StylePropertyMap", "declarations"): (("declaration", "MutableStylePropertyMap"),),
    # Parser and NumericType hold these values directly instead of exposing
    # one-line accessors/mutators around the record fields.
    ("Parser", "document"): (("document", "ParsingParams"),),
    ("NumericType", "set_percent_hint"): (("percent_hint", "NumericType"),),
    # Import and namespace subclasses are discriminated CSSRule records in V.
    ("CSSImportRule", "url"): (("url", "CSSRule"),),
    ("CSSImportRule", "loaded_style_sheet"): (("loaded_style_sheet", "CSSRule"),),
    ("CSSImportRule", "internal_layer_name"): (("layer_internal", "CSSRule"),),
    ("CSSImportRule", "parent_style_sheet_for_subresource"): (
        ("parent_style_sheet", "CSSRule"),
    ),
    ("CSSNamespaceRule", "set_namespace_uri"): (("namespace_uri", "CSSRule"),),
    ("CSSNamespaceRule", "set_prefix"): (("prefix", "CSSRule"),),
    # Color base-class properties are embedded directly by each concrete sum
    # variant. Require both modern/legacy variants for shared abstract bases.
    ("HSLColorStyleValue", "h"): (("h_", "HSLColorStyleValue"),),
    ("HSLColorStyleValue", "s"): (("s_", "HSLColorStyleValue"),),
    ("HSLColorStyleValue", "l"): (("l_", "HSLColorStyleValue"),),
    ("HSLColorStyleValue", "alpha"): (("alpha_", "HSLColorStyleValue"),),
    ("HWBColorStyleValue", "h"): (("h_", "HWBColorStyleValue"),),
    ("HWBColorStyleValue", "w"): (("w_", "HWBColorStyleValue"),),
    ("HWBColorStyleValue", "b"): (("b_", "HWBColorStyleValue"),),
    ("HWBColorStyleValue", "alpha"): (("alpha_", "HWBColorStyleValue"),),
    ("LCHLikeColorStyleValue", "l"): (
        ("l_", "LCHColorStyleValue"), ("l_", "OKLCHColorStyleValue"),
    ),
    ("LCHLikeColorStyleValue", "c"): (
        ("c_", "LCHColorStyleValue"), ("c_", "OKLCHColorStyleValue"),
    ),
    ("LCHLikeColorStyleValue", "h"): (
        ("h_", "LCHColorStyleValue"), ("h_", "OKLCHColorStyleValue"),
    ),
    ("LCHLikeColorStyleValue", "alpha"): (
        ("alpha_", "LCHColorStyleValue"), ("alpha_", "OKLCHColorStyleValue"),
    ),
    ("LabLikeColorStyleValue", "l"): (
        ("l_", "LabColorStyleValue"), ("l_", "OKLabColorStyleValue"),
    ),
    ("LabLikeColorStyleValue", "a"): (
        ("a_", "LabColorStyleValue"), ("a_", "OKLabColorStyleValue"),
    ),
    ("LabLikeColorStyleValue", "b"): (
        ("b_", "LabColorStyleValue"), ("b_", "OKLabColorStyleValue"),
    ),
    ("LabLikeColorStyleValue", "alpha"): (
        ("alpha_", "LabColorStyleValue"), ("alpha_", "OKLabColorStyleValue"),
    ),
    # Gradient color-stop accessors are direct reads of the concrete V records.
    ("LinearGradientStyleValue", "color_stop_list"): (
        ("color_stop_list_", "LinearGradientStyleValue"),
    ),
    ("RadialGradientStyleValue", "color_stop_list"): (
        ("color_stop_list_", "RadialGradientStyleValue"),
    ),
    ("ConicGradientStyleValue", "color_stop_list"): (
        ("color_stop_list_", "ConicGradientStyleValue"),
    ),
    ("CSSStyleProperties", "properties"): (("properties", "CSSStyleProperties"),),
    ("CSSStyleProperties", "custom_properties"): (
        ("custom_properties", "CSSStyleProperties"),
    ),
    ("CSSDescriptors", "descriptors"): (("descriptors", "CSSDescriptors"),),
    # Rule subclasses and computed-value wrappers are discriminated records.
    ("CSSFontFaceRule", "parent_style_sheet_for_subresource"): (
        ("parent_style_sheet", "CSSRule"),
    ),
    ("CSSKeyframeRule", "key"): (("keyframe_key", "CSSRule"),),
    ("CSSNestedDeclarations", "declaration"): (("declaration", "CSSRule"),),
    ("CSSPageRule", "descriptors"): (("page_descriptors", "CSSRule"),),
    ("CSSRule", "type"): (("type_", "CSSRule"),),
    ("CSSStyleRule", "declaration"): (("declaration", "CSSRule"),),
    ("CSSStyleValue", "associated_property"): (("associated_property", "CSSStyleValue"),),
    ("SVGPaint", "m_value"): (("value_", "SVGPaint"),),
    ("StyleSheet", "parent_style_sheet"): (("parent_style_sheet", "StyleSheet"),),
    ("StyleSheetList", "document_or_shadow_root"): (
        ("document_or_shadow_root", "StyleSheetList"),
    ),
    # The C++ calculation-node accessors become fields on V's tagged records.
    ("CalculatedStyleValue", "calculation"): (("node", "CalculatedStyleValue"),),
    ("SumCalculationNode", "children"): (("children", "CalcSum"),),
    ("ProductCalculationNode", "children"): (("children", "CalcProduct"),),
    ("NegateCalculationNode", "children"): (("children", "CalcNegate"),),
    ("NegateCalculationNode", "child"): (("children", "CalcNegate"),),
    ("InvertCalculationNode", "children"): (("children", "CalcInvert"),),
    ("InvertCalculationNode", "child"): (("children", "CalcInvert"),),
    ("AbsCalculationNode", "children"): (("children", "CalcFunction"),),
    ("SignCalculationNode", "children"): (("children", "CalcFunction"),),
    ("SinCalculationNode", "children"): (("children", "CalcFunction"),),
    ("CosCalculationNode", "children"): (("children", "CalcFunction"),),
    ("TanCalculationNode", "children"): (("children", "CalcFunction"),),
    ("AsinCalculationNode", "children"): (("children", "CalcFunction"),),
    ("AcosCalculationNode", "children"): (("children", "CalcFunction"),),
    ("AtanCalculationNode", "children"): (("children", "CalcFunction"),),
    ("Atan2CalculationNode", "children"): (("children", "CalcFunction"),),
    ("PowCalculationNode", "children"): (("children", "CalcFunction"),),
    ("SqrtCalculationNode", "children"): (("children", "CalcFunction"),),
    ("LogCalculationNode", "children"): (("children", "CalcFunction"),),
    ("ExpCalculationNode", "children"): (("children", "CalcFunction"),),
    ("RoundCalculationNode", "rounding_strategy"): (("strategy", "CalcFunction"),),
    ("RoundCalculationNode", "children"): (("children", "CalcFunction"),),
    ("ModCalculationNode", "children"): (("children", "CalcFunction"),),
    ("RemCalculationNode", "children"): (("children", "CalcFunction"),),
    ("MinCalculationNode", "children"): (("children", "CalcFunction"),),
    ("MaxCalculationNode", "children"): (("children", "CalcFunction"),),
    ("ClampCalculationNode", "children"): (("children", "CalcFunction"),),
    ("HypotCalculationNode", "children"): (("children", "CalcFunction"),),
    ("NonMathFunctionCalculationNode", "function"): (
        ("style_value", "CalcTreeCounting"),
    ),
    ("RandomCalculationNode", "children"): (("children", "CalcRandom"),),
    # C++ exposes iterator pairs and stylesheet state through inline methods;
    # V exposes the same retained collections directly on typed records.
    ("CSSRuleList", "begin"): (("rules", "CSSRuleList"),),
    ("CSSRuleList", "end"): (("rules", "CSSRuleList"),),
    ("Subresource", "loading_state"): (("loading_state", "CSSRule"),),
    ("CSSStyleSheet", "owner_rule"): (("owner_rule", "CSSStyleSheet"),),
    ("CSSStyleSheet", "owning_documents_or_shadow_roots"): (
        ("owning_documents_or_shadow_roots", "CSSStyleSheet"),
    ),
    ("CSSStyleSheet", "default_namespace_rule"): (
        ("default_namespace_rule", "CSSStyleSheet"),
    ),
    ("CSSStyleSheet", "import_rules"): (("import_rules", "CSSStyleSheet"),),
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

    # TrackBuffer exposes its demuxer as immutable typed state in V; all
    # timestamp getters and mutations retain explicit methods.
    ("TrackBuffer", "demuxer"): (("demuxer", "TrackBuffer"),),
}

# Some V modules deliberately consolidate private C++ helpers into a shared
# implementation or give them a module-specific prefix to avoid collisions.
# These mappings are source-qualified and are accepted only while every named
# V target still exists, so they cannot silently turn stale documentation into
# coverage.
CONSOLIDATED_FUNCTION_MAPPINGS: dict[tuple[str, str], tuple[str, ...]] = {
    # The text-control lookup is fused into V's replace-data command factory,
    # which records the live InputEventsTarget used by every replay. The
    # callback-shaped traversal returns the same tree-order nodes as a list for
    # direct iteration at each translated call site.
    ("EditCommand.cpp", "text_control_owner_of"): (
        "new_replace_data_command",
    ),
    ("Internal/Algorithms.cpp", "for_each_node_effectively_contained_in_range"): (
        "nodes_effectively_contained_in_range",
    ),
    # SVGLength keeps the reflected attribute's viewport/font context in its
    # portable value object. The C++ free helpers become the context builder
    # and the percentage-basis method that consume that retained state.
    ("SVGLength.cpp", "percentage_resolution_basis_for_attribute_reflecting_length"): (
        "percentage_resolution_basis",
    ),
    ("SVGLength.cpp", "length_resolution_context_for_element"): (
        "svg_length_context_from_element",
    ),
    ("SVGLength.cpp", "parse_css_length_value"): (
        "parse_svg_length_scalar",
        "is_supported_non_scalar_svg_length",
    ),
    ("SVGLength.cpp", "convert_px_to_specified_units"): (
        "px_to_unit",
    ),
    ("SVGLength.cpp", "svg_length_type_to_css_length_unit"): (
        "length_unit_from_type",
    ),
    # V checks the name/element restrictions while collecting the live SVG
    # attribute set, so it needs neither a pointer lookup table nor a separate
    # property-id probe.
    ("SVGElement.cpp", "attribute_style_properties_by_name"): (
        "collect_svg_presentational_hints",
    ),
    ("SVGElement.cpp", "property_id_for_presentational_attribute"): (
        "collect_svg_presentational_hints",
    ),
    # AnimationUpdateContext teardown is folded into the CSS-owned callback in
    # V to avoid the css -> animations import cycle. That callback directly
    # reads and compares the translated animated property maps, so the small
    # Rust-overlay span adapter has no separate V representation.
    ("AnimationEffect.cpp", "animated_overlay_entries"): (
        "style_computer_update_animated_style_callback",
    ),
    # Both ARIA callers share the same translated tokenizer. The C++ helper
    # drives a callback; V returns the tokens for direct iteration.
    ("ARIAMixin.cpp", "for_each_ascii_whitespace_separated_token"): (
        "ascii_whitespace_separated_tokens",
    ),
    ("AriaData.cpp", "for_each_ascii_whitespace_separated_token"): (
        "ascii_whitespace_separated_tokens",
    ),
    ("ISOBMFFByteStreamParser.cpp", "read_top_level_box_header"): (
        "read_iso_box_header",
    ),
    ("SourceBufferProcessor.cpp", "codecs_are_supported"): (
        "initialization_codecs_are_supported",
    ),
    ("CSSDescriptors.cpp", "is_shorthand"): ("is_descriptor_shorthand",),
    ("CSSDescriptors.cpp", "for_each_expanded_longhand"): (
        "for_each_expanded_descriptor_longhand",
    ),
    # Numeric and indexed WebIDL conversions operate on already-narrowed V sum
    # types, but retain the same validation/reification algorithms.
    ("CSSNumericValue.cpp", "to_om_numeric_base_type"): ("base_type_name",),
    ("CSSNumericValue.cpp", "reify_a_numeric_value"): (
        "css_numeric_value_reify_component_value",
    ),
    ("CSSPerspective.cpp", "to_internal"): ("to_internal_css_perspective_value",),
    ("CSSTransformValue.cpp", "transform_component_from_js_value"): (
        "transform_component_from_value",
    ),
    ("CSSUnparsedValue.cpp", "unparsed_segment_from_js_value"): (
        "unparsed_segment_from_indexed_value",
    ),
    ("Parser/RuleContext.cpp", "rule_context_type_for_at_rule"): (
        "rule_context_type_for_at_rule_local",
    ),
    ("PropertyName.h", "is_invalid_custom_property_name_string"): (
        "is_invalid_custom_property_name_string_local",
    ),
    ("PropertyName.h", "is_a_valid_css_property"): ("from_name",),
    ("Selector.cpp", "component_value_contains_nesting_selector"): (
        "selector_contains_nesting_uncached",
    ),
    ("Serialize.h", "serialize_a_comma_separated_list"): (
        "serialize_a_comma_separated_string_list",
    ),
    ("CSSStyleProperties.cpp", "style_value_for_length_percentage"): (
        "cssom_style_value_for_length_percentage",
    ),
    ("CSSStyleProperties.cpp", "style_value_for_length_percentage_or_auto"): (
        "cssom_style_value_for_length_percentage_or_auto",
    ),
    ("CSSStyleProperties.cpp", "style_value_for_size"): (
        "cssom_style_value_for_size",
    ),
    ("CSSStyleProperties.cpp", "style_value_for_shadow"): (
        "cssom_style_value_for_shadow",
    ),
    ("CSSStyleProperties.cpp", "resolve_color_style_value"): (
        "cssom_resolve_color_style_value",
    ),
    ("StyleScope.cpp", "default_stylesheet"): ("user_agent_default_style_sheet",),
    ("StyleScope.cpp", "quirks_mode_stylesheet"): ("user_agent_default_style_sheet",),
    ("StyleScope.cpp", "mathml_stylesheet"): ("user_agent_default_style_sheet",),
    ("StyleScope.cpp", "svg_stylesheet"): ("user_agent_default_style_sheet",),
    ("Parser/SelectorParsing.cpp", "create_invalid_selector"): (
        "invalid_simple_selector",
    ),
    # The virtual C++ calculation tree is decomposed into typed V operations.
    # Three add_the_types overloads intentionally share the same mapping.
    ("StyleValues/CalculatedStyleValue.cpp", "add_the_types"): ("added_to",),
    ("StyleValues/CalculatedStyleValue.cpp", "multiply_the_types"): ("multiplied_by",),
    ("StyleValues/CalculatedStyleValue.cpp", "simplify_children_vector"): ("simplify_calc",),
    ("StyleValues/CalculatedStyleValue.cpp", "simplify_child"): ("simplify_calc",),
    ("StyleValues/CalculatedStyleValue.cpp", "simplify_2_children"): ("simplify_calc",),
    ("StyleValues/CalculatedStyleValue.cpp", "clamp_and_censor_numeric_value"): ("clamp_and_censor",),
    ("StyleValues/CalculatedStyleValue.cpp", "serialize_a_math_function"): ("serialize_top",),
    ("StyleValues/CalculatedStyleValue.cpp", "numeric_type_from_calculated_style_value"): ("numeric_type",),
    ("StyleValues/CalculatedStyleValue.cpp", "try_get_value_with_canonical_unit"): ("resolve_calc_leaf",),
    ("StyleValues/CalculatedStyleValue.cpp", "try_get_number"): ("resolve_calc_node",),
    ("StyleValues/CalculatedStyleValue.cpp", "run_min_or_max_operation_if_possible"): ("resolve_calc_function",),
    ("StyleValues/CalculatedStyleValue.cpp", "run_sin_cos_or_tan_operation_if_possible"): ("resolve_calc_function",),
    ("StyleValues/CalculatedStyleValue.cpp", "run_asin_acos_or_atan_operation_if_possible"): ("resolve_calc_function",),
    ("StyleValues/CalculatedStyleValue.cpp", "run_mod_or_rem_operation_if_possible"): ("calc_mod_or_rem",),
    ("StyleValues/CalculatedStyleValue.cpp", "find_numeric_child_with_same_unit"): ("simplify_calc_sum",),
    ("StyleValues/CalculatedStyleValue.cpp", "simplify_a_calculation_tree"): ("simplify_calc_with_resolution",),
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
    ("BackgroundPainting.cpp", "get_box"): ("background_box_for_kind",),
    ("BackgroundPainting.cpp", "paint_background"): ("paintable_box_paint_background",),
    # Skia conversion helpers stop at V's renderer boundary. Geometry and
    # gradient/tile policy remain represented in typed command values, while
    # the native shell performs the final backend conversion.
    ("DisplayListPlayerSkia.cpp", "to_skia_rrect"): ("as_corners",),
    ("DisplayListPlayerSkia.cpp", "to_skia_matrix"): ("map_point",),
    ("DisplayListPlayerSkia.cpp", "to_skia_matrix4x4"): (
        "transform_point_for_hit_test",
    ),
    ("DisplayListPlayerSkia.cpp", "to_skia_interpolation"): (
        "expand_color_stops_for_painting",
    ),
    ("DisplayListPlayerSkia.cpp", "to_skia_tile_mode"): ("background_tile_plan",),
    ("DisplayListPlayerSkia.cpp", "gradient_paint_style_to_skia_paint"): (
        "expand_color_stops_for_painting",
    ),
    ("BoxViews.cpp", "set_paint_viewport_scrollbars"): (
        "set_paint_viewport_scrollbars",
    ),
    ("SVGPathPaintable.cpp", "to_gfx_winding_rule"): ("paint_commands",),
    ("StackingContext.cpp", "to_paint_phase"): ("compatibility_paint_plan",),
    ("TableBordersPainting.cpp", "css_border_data_from_device_border_data"): (
        "device_border_data_from_css_border_data",
    ),
    ("ViewportPaintable.cpp", "scale_matrix_for_device_pixels"): (
        "painting_affine_from_svg",
    ),
    ("ViewportPaintable.cpp", "compute_transform"): (
        "resolved_computed_transform_matrix",
    ),
    ("ViewportPaintable.cpp", "compute_perspective_matrix"): (
        "viewport_assign_accumulated_visual_contexts",
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
    # Interpolation's large C++ visitor is split into property entry points and
    # recursive StyleValue-sum dispatch in V.
    ("Interpolation.cpp", "with_keyword_values_resolved"): ("with_keyword_values_resolved_boundary",),
    ("Interpolation.cpp", "interpolate_scale"): ("interpolate_scale_property",),
    ("Interpolation.cpp", "interpolate_translate"): ("interpolate_translate_property",),
    ("Interpolation.cpp", "interpolate_rotate"): ("interpolate_rotate_property",),
    ("Interpolation.cpp", "interpolate_mixed_value"): ("interpolate_mixed_style_value",),
    ("Interpolation.cpp", "interpolate_value_impl"): ("interpolate_style_value_impl",),
    ("Interpolation.cpp", "composite_raw_values"): ("composite_style_value",),
    ("Interpolation.cpp", "composite_mixed_value"): ("composite_mixed_style_value",),
    ("FontComputer.cpp", "style_value_references_font_family"): ("computed_font_cache_key_references_family",),
    ("FontFace.cpp", "load_vector_font"): ("platform_load_font_from_bytes_boundary",),
    # The V parser performs these tiny file-local operations directly at their
    # only active consumer rather than retaining generic callback wrappers.
    ("Parser/GradientParsing.cpp", "consume_if_starts_with"): ("parse_linear_gradient_function",),
    ("SelectorEngine.cpp", "for_each_matching_attribute"): ("matching_attributes",),
    # Color-space enum conversion and radial-corner geometry retain the same
    # exhaustive match and Euclidean-distance algorithms under clearer names.
    ("StyleValues/ColorFunctionStyleValue.cpp", "color_type_from_string_view"): ("color_type_from_color_space",),
    ("StyleValues/ColorFunctionStyleValue.cpp", "string_view_from_color_type"): ("color_space_from_color_type",),
    ("StyleValues/RadialSizeStyleValue.cpp", "closest_corner_distance"): ("style_values_extra_corner_distance",),
    ("StyleValues/RadialSizeStyleValue.cpp", "farthest_corner_distance"): ("style_values_extra_corner_distance",),
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
            elif (class_name, method_name) in LANGUAGE_ARTIFACT_METHODS:
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
                elif (source_path, function_name) in LANGUAGE_ARTIFACT_FREE_FUNCTIONS:
                    disposition = "language-template-trait"
                elif (source_path, function_name) in RUNTIME_ONLY_FREE_FUNCTIONS:
                    disposition = "gc-or-binding-runtime"
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
                            elif (class_name, method_name) in LANGUAGE_ARTIFACT_METHODS:
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
