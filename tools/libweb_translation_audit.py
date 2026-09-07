#!/usr/bin/env python3
"""Audit implementation-symbol coverage for every upstream LibWeb module.

Filename inventories can establish that a source unit has a translation home,
but they cannot detect omitted methods or free functions inside that unit.  This
tool applies the stricter HTML audit's symbol extraction to all module-owned
LibWeb C++ sources and matches them against non-test V functions workspace-wide.
"""

from __future__ import annotations

import argparse
import collections
import fnmatch
import json
import re
from dataclasses import asdict
from pathlib import Path

import html_translation_audit as html_audit


EXCLUDED_TRANSLATION_DIRECTORIES = {
    ".git",
    "Build",
    "third_party",
}

# These files were introduced as symbol-coverage shims: they expose upstream
# names, frequently through simplified state records, but are not source-unit
# ports. Keeping them out of the implementation inventory prevents a name-only
# facade from making a module appear translated. Reviewed implementations
# belong with the real subsystem, not in one of these quarantine files.
UNREVIEWED_COVERAGE_SHIMS = (
    "upstream_*entry_points.v",
    "upstream_*entry_points_*.v",
)

SEMANTIC_DIVERGENCE_MARKERS = (
    re.compile(r"\bnot translated\b", re.IGNORECASE),
    re.compile(r"\bexplicit (?:local )?stubs?\b", re.IGNORECASE),
    re.compile(r"\bstub for\b", re.IGNORECASE),
    re.compile(r"\bstub:\s", re.IGNORECASE),
    re.compile(r"\bapproximation\b|\bapproximated\b", re.IGNORECASE),
    re.compile(r"\bsimplified from\b", re.IGNORECASE),
    re.compile(r"\bnot represented\b", re.IGNORECASE),
    re.compile(r"\bnot fully present\b", re.IGNORECASE),
    re.compile(r"\bnot supported yet\b", re.IGNORECASE),
    re.compile(r"\bnot (?:implemented|ported|translated) yet\b", re.IGNORECASE),
    re.compile(r"\bfrom[- ]scratch\b", re.IGNORECASE),
    re.compile(r"\blocally simplified\b", re.IGNORECASE),
    re.compile(
        r"\b(?:compact|minimal|lightweight) (?:cascade|layout|renderer|implementation|engine|model|path)\b",
        re.IGNORECASE,
    ),
    re.compile(r"\b(?:intentionally|deliberately) (?:omit|omits|outside)\b", re.IGNORECASE),
    re.compile(r"\bstandalone fallback\b", re.IGNORECASE),
    re.compile(r"\buntil .+ (?:is|are) ported\b", re.IGNORECASE),
    re.compile(r"\b(?:struct|interface)\s+\w*(?:Facade|Stub)\b"),
)

TRIVIAL_RETURN = re.compile(
    r"^return\s+(?:none|false|true|0(?:\.0+)?|''|\"\"|\[\]|"
    r"map\[[^\]]+\][A-Za-z_]\w*\{\}|&?[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)?\{\})$"
)

# These implementations were compared directly with the current upstream body.
# Keeping the exact source/owner/name tuple here makes reviewed constants and
# no-ops visible without repeatedly returning them to the investigation queue.
VERIFIED_TRIVIAL_IMPLEMENTATIONS: frozenset[tuple[str, str | None, str]] = frozenset(
    {
        # AnimationEffect's virtual target default and the legacy
        # NavigationTiming/PerformanceTiming getters are constants upstream.
        ("animations/animation_effect.v", "AnimationEffect", "target"),
        ("navigationtiming/navigation_timing.v", "PerformanceTiming", "unload_event_start"),
        ("navigationtiming/navigation_timing.v", "PerformanceTiming", "unload_event_end"),
        ("navigationtiming/navigation_timing.v", "PerformanceTiming", "redirect_start"),
        ("navigationtiming/navigation_timing.v", "PerformanceTiming", "redirect_end"),
        ("navigationtiming/navigation_timing.v", "PerformanceTiming", "fetch_start"),
        ("navigationtiming/navigation_timing.v", "PerformanceTiming", "domain_lookup_start"),
        ("navigationtiming/navigation_timing.v", "PerformanceTiming", "domain_lookup_end"),
        ("navigationtiming/navigation_timing.v", "PerformanceTiming", "connect_start"),
        ("navigationtiming/navigation_timing.v", "PerformanceTiming", "connect_end"),
        ("navigationtiming/navigation_timing.v", "PerformanceTiming", "secure_connection_start"),
        ("navigationtiming/navigation_timing.v", "PerformanceTiming", "request_start"),
        ("navigationtiming/navigation_timing.v", "PerformanceTiming", "response_start"),
        ("navigationtiming/navigation_timing.v", "PerformanceTiming", "response_end"),
        ("navigationtiming/navigation_timing.v", "PerformanceTiming", "dom_loading"),
        # Every unit in these generated non-length dimensions is absolute.
        ("css/css.v", None, "angle_units_are_compatible"),
        ("css/css.v", None, "frequency_units_are_compatible"),
        ("css/css.v", None, "flex_units_are_compatible"),
        ("css/css.v", None, "resolution_units_are_compatible"),
        ("css/css.v", None, "time_units_are_compatible"),
        # CSS Typed OM specifies that these is2D setters do nothing.
        ("css/transforms.v", "CSSPerspective", "set_is_2d"),
        ("css/transforms.v", "CSSSkew", "set_is_2d"),
        ("css/transforms.v", "CSSSkewX", "set_is_2d"),
        ("css/transforms.v", "CSSSkewY", "set_is_2d"),
        # DOM base-class defaults and the Attr specified compatibility getter.
        ("dom/character_nodes.v", "Attr", "specified"),
        ("dom/element.v", "Element", "is_implicitly_potentially_render_blocking"),
        ("dom/shadow_mutation_misc.v", "Element", "contributes_a_script_blocking_style_sheet"),
        ("dom/events.v", "EventTarget", "has_activation_behavior"),
        ("dom/events.v", "EventTarget", "activation_behavior"),
        ("dom/events.v", "EventTarget", "legacy_pre_activation_behavior"),
        ("dom/events.v", "EventTarget", "legacy_cancelled_activation_behavior"),
        ("dom/events.v", "EventTarget", "legacy_cancelled_activation_behavior_was_not_called"),
        ("dom/events.v", "EventTarget", "is_universal_global_scope_mixin"),
        # DOM core headers define these identity and base-class hooks inline.
        ("dom/inline_state.v", "Element", "is_dom_element"),
        ("dom/inline_state.v", "Element", "supports_dimension_attributes"),
        ("dom/inline_state.v", "Element", "is_presentational_hint"),
        ("dom/inline_state.v", "Element", "apply_presentational_hints"),
        ("dom/inline_state.v", "Element", "did_receive_focus"),
        ("dom/inline_state.v", "Element", "did_lose_focus"),
        ("dom/inline_state.v", "Element", "computed_properties_changed"),
        ("dom/inline_state.v", "Event", "is_dom_event"),
        ("dom/inline_state.v", "EventTarget", "is_dom_event_target"),
        ("dom/inline_state.v", "ShadowRoot", "is_shadow_root"),
        ("dom/inline_state.v", "Document", "is_dom_document"),
        # These DOM lifecycle bodies only install WebIDL prototypes and call
        # binding/runtime base initializers, which this V layer does not have.
        ("dom/character_nodes.v", "Attr", "initialize"),
        ("dom/character_nodes.v", "CharacterData", "initialize"),
        ("dom/character_nodes.v", "Text", "initialize"),
        ("dom/character_nodes.v", "Comment", "initialize"),
        ("dom/character_nodes.v", "CDATASection", "finalize"),
        ("dom/character_nodes.v", "CDATASection", "initialize"),
        ("dom/character_nodes.v", "ProcessingInstruction", "initialize"),
        ("dom/character_nodes.v", "DocumentType", "initialize"),
        ("dom/character_nodes.v", "DocumentFragment", "initialize"),
        # Event constructors below only default-initialize translated state;
        # initialize remains a WebIDL prototype hook upstream.
        ("dom/events.v", None, "js_undefined"),
        ("dom/events.v", "Event", "initialize"),
        ("dom/events.v", "DOMEventListener", "new"),
        ("dom/events.v", "EventTarget", "construct_impl"),
        ("dom/events.v", "EventTarget", "new"),
        ("dom/events.v", "AbortSignal", "construct_impl"),
        ("dom/events.v", "AbortSignal", "new"),
        ("dom/events.v", "AbortController", "initialize"),
        # Mutation/ShadowRoot/DOMImplementation/XMLDocument initialization is
        # binding-only; the other bodies are exact header defaults. The V
        # invalidator keys pending work by node ID, so it has no GC edge to visit.
        ("dom/shadow_mutation_misc.v", "MutationRecord", "initialize"),
        ("dom/shadow_mutation_misc.v", "MutationObserver", "initialize"),
        ("dom/shadow_mutation_misc.v", "TransientRegisteredObserver", "is_transient"),
        ("dom/shadow_mutation_misc.v", "ShadowRoot", "initialize"),
        ("dom/shadow_mutation_misc.v", "StyleInvalidator", "visit_edges"),
        ("dom/shadow_mutation_misc.v", "DOMImplementation", "initialize"),
        ("dom/shadow_mutation_misc.v", "DOMImplementation", "has_feature"),
        ("dom/shadow_mutation_misc.v", "XMLDocument", "initialize"),
        # HTMLInputElement and HTMLSelectElement override these with constants upstream.
        ("html/html_input_element.v", "HTMLInputElementModel", "is_html_input_element"),
        ("html/html_input_element.v", "HTMLInputElementModel", "current_frame_index"),
        ("html/html_input_element.v", "HTMLInputElementModel", "has_activation_behavior"),
        ("html/html_input_element.v", "HTMLInputElementModel", "is_listed"),
        ("html/html_input_element.v", "HTMLInputElementModel", "is_submittable"),
        ("html/html_input_element.v", "HTMLInputElementModel", "is_resettable"),
        (
            "html/html_input_element.v",
            "HTMLInputElementModel",
            "is_autocapitalize_and_autocorrect_inheriting",
        ),
        ("html/html_input_element.v", "HTMLInputElementModel", "default_tab_index_value"),
        ("html/html_select_element.v", "HTMLSelectElementModel", "is_html_select_element"),
        ("html/html_select_element.v", "HTMLSelectElementModel", "is_listed"),
        ("html/html_select_element.v", "HTMLSelectElementModel", "is_submittable"),
        ("html/html_select_element.v", "HTMLSelectElementModel", "is_resettable"),
        (
            "html/html_select_element.v",
            "HTMLSelectElementModel",
            "is_autocapitalize_and_autocorrect_inheriting",
        ),
        ("html/html_select_element.v", "HTMLSelectElementModel", "is_labelable"),
        ("html/html_select_element.v", "HTMLSelectElementModel", "default_tab_index_value"),
        ("html/html_select_element.v", "HTMLSelectElementModel", "has_activation_behavior"),
        # The simple HTML element headers define these identity/default hooks inline.
        ("html/header_inline_elements.v", None, "html_br_element_is_html_br_element"),
        ("html/header_inline_elements.v", None, "html_base_element_is_html_base_element"),
        ("html/header_inline_elements.v", None, "html_div_element_is_html_div_element"),
        ("html/header_inline_elements.v", None, "html_embed_element_is_html_embed_element"),
        ("html/header_inline_elements.v", None, "html_form_element_is_html_form_element"),
        ("html/header_inline_elements.v", None, "html_head_element_is_html_head_element"),
        ("html/header_inline_elements.v", None, "html_heading_element_is_html_heading_element"),
        ("html/header_inline_elements.v", None, "html_html_element_is_html_html_element"),
        ("html/header_inline_elements.v", None, "html_li_element_is_html_li_element"),
        ("html/header_inline_elements.v", None, "html_link_element_is_html_link_element"),
        ("html/header_inline_elements.v", None, "html_menu_element_is_html_menu_element"),
        ("html/header_inline_elements.v", None, "html_olist_element_is_html_olist_element"),
        ("html/header_inline_elements.v", None, "html_opt_group_element_is_html_optgroup_element"),
        ("html/header_inline_elements.v", None, "html_option_element_is_html_option_element"),
        ("html/header_inline_elements.v", None, "html_progress_element_is_html_progress_element"),
        ("html/header_inline_elements.v", None, "html_script_element_is_html_script_element"),
        ("html/header_inline_elements.v", None, "html_span_element_is_html_span_element"),
        ("html/header_inline_elements.v", None, "html_table_cell_element_is_html_table_cell_element"),
        ("html/header_inline_elements.v", None, "html_table_element_is_html_table_element"),
        ("html/header_inline_elements.v", None, "html_table_row_element_is_html_table_row_element"),
        (
            "html/header_inline_elements.v",
            None,
            "html_table_section_element_is_html_table_section_element",
        ),
        ("html/header_inline_elements.v", None, "html_template_element_is_html_template_element"),
        ("html/header_inline_elements.v", None, "html_title_element_is_html_title_element"),
        ("html/header_inline_elements.v", None, "html_ulist_element_is_html_ulist_element"),
        ("html/header_inline_elements.v", None, "html_anchor_element_is_html_anchor_element"),
        ("html/header_inline_elements.v", None, "html_area_element_is_html_area_element"),
        ("html/header_inline_elements.v", None, "html_body_element_is_html_body_element"),
        ("html/header_inline_elements.v", None, "html_button_element_is_listed"),
        ("html/header_inline_elements.v", None, "html_button_element_is_submittable"),
        (
            "html/header_inline_elements.v",
            None,
            "html_button_element_is_autocapitalize_and_autocorrect_inheriting",
        ),
        ("html/header_inline_elements.v", None, "html_button_element_is_button"),
        ("html/header_inline_elements.v", None, "html_button_element_is_labelable"),
        ("html/header_inline_elements.v", None, "html_button_element_uses_button_layout"),
        ("html/header_inline_elements.v", None, "html_button_element_is_html_button_element"),
        ("html/header_inline_elements.v", None, "html_element_is_labelable"),
        ("html/header_inline_elements.v", None, "html_element_is_valid_command"),
        ("html/header_inline_elements.v", None, "html_element_command_steps"),
        ("html/header_inline_elements.v", None, "html_element_uses_button_layout"),
        ("html/header_inline_elements.v", None, "html_element_is_html_element"),
        ("html/header_inline_elements.v", None, "html_field_set_element_is_listed"),
        (
            "html/header_inline_elements.v",
            None,
            "html_field_set_element_is_autocapitalize_and_autocorrect_inheriting",
        ),
        ("html/header_inline_elements.v", None, "html_field_set_element_is_html_fieldset_element"),
        ("html/header_inline_elements.v", None, "html_frame_set_element_is_html_frameset_element"),
        ("html/header_inline_elements.v", None, "html_iframe_element_is_focusable"),
        ("html/header_inline_elements.v", None, "html_iframe_element_is_html_iframe_element"),
        ("html/header_inline_elements.v", None, "html_iframe_element_supports_dimension_attributes"),
        ("html/header_inline_elements.v", None, "html_image_element_is_html_image_element"),
        ("html/header_inline_elements.v", None, "html_image_element_supports_dimension_attributes"),
        ("html/header_inline_elements.v", None, "html_output_element_is_listed"),
        ("html/header_inline_elements.v", None, "html_output_element_is_resettable"),
        (
            "html/header_inline_elements.v",
            None,
            "html_output_element_is_autocapitalize_and_autocorrect_inheriting",
        ),
        ("html/header_inline_elements.v", None, "html_output_element_is_labelable"),
        ("html/header_inline_elements.v", None, "html_slot_element_is_html_slot_element"),
        ("html/header_inline_elements.v", None, "html_style_element_is_html_style_element"),
        ("html/header_inline_elements.v", None, "html_text_area_element_is_listed"),
        ("html/header_inline_elements.v", None, "html_text_area_element_is_submittable"),
        ("html/header_inline_elements.v", None, "html_text_area_element_is_resettable"),
        (
            "html/header_inline_elements.v",
            None,
            "html_text_area_element_is_autocapitalize_and_autocorrect_inheriting",
        ),
        ("html/header_inline_elements.v", None, "html_text_area_element_is_labelable"),
        ("html/header_inline_elements.v", None, "html_text_area_element_is_html_textarea_element"),
        # DisplayListCommand.cpp deliberately emits no detail for stateless commands.
        ("painting/display_list.v", "Save", "dump"),
        ("painting/display_list.v", "SaveLayer", "dump"),
        ("painting/display_list.v", "Restore", "dump"),
        ("painting/display_list.v", "AddClipRect", "is_clip"),
        ("painting/display_list.v", "StrokePath", "dump"),
        ("painting/display_list.v", "AddRoundedRectClip", "is_clip"),
        ("painting/display_list.v", "PaintScrollbar", "dump"),
        # These Event Timing accessors are still explicit zero/null FIXMEs upstream.
        ("eventtiming/performance_event_timing.v", "PerformanceEventTiming", "processing_end"),
        ("eventtiming/performance_event_timing.v", "PerformanceEventTiming", "processing_start"),
        ("eventtiming/performance_event_timing.v", "PerformanceEventTiming", "target"),
        ("eventtiming/performance_event_timing.v", "PerformanceEventTiming", "interaction_id"),
        # SVGGeometryElement currently returns zero and an origin DOMPoint upstream.
        ("svg/element_operations.v", "Element", "get_total_length"),
        ("svg/element_operations.v", "Element", "get_point_at_length"),
        # SVGTransform.cpp still implements these bindings as explicit FIXMEs.
        ("svg/value_operations.v", "Transform", "angle"),
        ("svg/value_operations.v", "Transform", "set_translate"),
        ("svg/value_operations.v", "Transform", "set_scale"),
        ("svg/value_operations.v", "Transform", "set_rotate"),
        ("svg/value_operations.v", "Transform", "set_skew_x"),
        ("svg/value_operations.v", "Transform", "set_skew_y"),
        # SVGSVGElement currently implements these as constants, empty lists,
        # identity objects, or compatibility no-ops upstream.
        ("svg/specialized_operations.v", "SvgViewport", "set_current_scale"),
        ("svg/specialized_operations.v", "SvgViewport", "current_translate"),
        ("svg/specialized_operations.v", "SvgViewport", "is_svg_container"),
        ("svg/specialized_operations.v", "SvgViewport", "requires_svg_container"),
        ("svg/specialized_operations.v", "SvgViewport", "unsuspend_redraw"),
        ("svg/specialized_operations.v", "SvgViewport", "unsuspend_redraw_all"),
        ("svg/specialized_operations.v", "SvgViewport", "force_redraw"),
        ("svg/specialized_operations.v", "SvgViewport", "check_intersection"),
        ("svg/specialized_operations.v", "SvgViewport", "check_enclosure"),
        ("svg/specialized_operations.v", "SvgViewport", "get_intersection_list"),
        ("svg/specialized_operations.v", "SvgViewport", "get_enclosure_list"),
        ("svg/specialized_operations.v", "SvgViewport", "create_svg_matrix"),
        ("svg/specialized_operations.v", "SvgViewport", "create_svg_point"),
        ("svg/specialized_operations.v", "SvgViewport", "create_svg_rect"),
        # BiquadFilterNode's frequency response hook is an explicit upstream no-op.
        ("webaudio/nodes.v", "BiquadFilterNode", "get_frequency_response"),
        # Reviewed DOM defaults and current pointer/view-transition placeholders.
        ("dom/node.v", "Node", "alternative_text"),
        ("dom/node.v", "Node", "post_connection"),
        ("dom/element.v", "Element", "capture_the_image"),
        ("dom/element.v", "Element", "set_pointer_capture"),
        ("dom/element.v", "Element", "release_pointer_capture"),
        ("dom/element.v", "Element", "has_pointer_capture"),
        # Current platform/spec boundaries with deliberately empty/default results.
        ("serial/serial_port.v", "SerialPort", "get_info"),
        ("websockets/web_socket.v", "WebSocket", "extensions"),
        ("html/pdf_viewer_plugins.v", "PluginArray", "refresh"),
        ("speech/synthesis.v", "SpeechSynthesis", "cancel"),
        ("html/html_media_element.v", "HTMLMediaElement", "stalled"),
        # Navigator exposes these exact current upstream compatibility defaults.
        ("html/navigator.v", "NavigatorOnLineMixin", "on_line"),
        ("html/navigator.v", "Navigator", "on_line"),
        ("html/navigator.v", "Navigator", "cookie_enabled"),
        ("html/navigator.v", "Navigator", "java_enabled"),
        ("html/navigator.v", "Navigator", "max_touch_points"),
        # Current HTML element headers/bodies define these identity, focus,
        # activation, and script-blocking defaults exactly as below.
        ("html/document_elements.v", "HTMLStyleElementModel", "create"),
        (
            "html/document_elements.v",
            "HTMLStyleElementModel",
            "contributes_a_script_blocking_style_sheet",
        ),
        (
            "html/document_elements.v",
            None,
            "html_style_element_contributes_a_script_blocking_style_sheet",
        ),
        ("html/document_elements.v", None, "html_area_element_default_tab_index_value"),
        ("html/document_elements.v", None, "html_anchor_element_has_activation_behavior"),
        ("html/document_elements.v", None, "html_anchor_element_default_tab_index_value"),
        ("html/document_elements.v", None, "html_label_element_has_activation_behavior"),
        ("html/embedded_content_elements.v", "NavigableContainerModel", "is_navigable_container"),
        (
            "html/embedded_content_elements.v",
            "HTMLIFrameElementModel",
            "supports_dimension_attributes",
        ),
        ("html/embedded_content_elements.v", None, "html_iframe_element_default_tab_index_value"),
        ("html/embedded_content_elements.v", "HTMLObjectElementModel", "is_listed"),
        (
            "html/embedded_content_elements.v",
            "HTMLObjectElementModel",
            "is_html_object_element",
        ),
        ("html/embedded_content_elements.v", "HTMLObjectElementModel", "current_frame_index"),
        ("html/embedded_content_elements.v", None, "html_object_element_default_tab_index_value"),
        # CSS guaranteed-invalid and pending-substitution values serialize empty upstream.
        ("css/parser_core.v", "GuaranteedInvalidValue", "to_string"),
        ("css/parser_core.v", "GuaranteedInvalidValue", "original_source_text"),
        ("css/style_values_core.v", "GuaranteedInvalidStyleValue", "create"),
        ("css/style_values_core.v", "GuaranteedInvalidStyleValue", "serialize"),
        ("css/style_values_core.v", "PendingSubstitutionStyleValue", "serialize"),
        # Generated property metadata has no properties accepting these dimensions.
        ("css/property_calculation_metadata.v", None, "property_accepts_angle"),
        ("css/property_calculation_metadata.v", None, "property_accepts_flex"),
        ("css/property_calculation_metadata.v", None, "property_accepts_frequency"),
        ("css/property_calculation_metadata.v", None, "property_accepts_resolution"),
        # CSSOM View permits these operations to return early; upstream always does so.
        ("html/window.v", "WindowModel", "move_to"),
        ("html/window.v", "WindowModel", "move_by"),
        ("html/window.v", "WindowModel", "resize_to"),
        ("html/window.v", "WindowModel", "resize_by"),
        ("html/window.v", "WindowModel", "capture_events"),
        ("html/window.v", "WindowModel", "release_events"),
        # Page.h supplies these exact defaults for embedders that do not override them.
        ("page/page_client.v", "PageClient", "is_url_suitable_for_same_process_navigation"),
        ("page/page_client.v", "PageClient", "page_did_request_document_cookie_version"),
        ("page/page_client.v", "PageClient", "page_did_request_all_cookies_webdriver"),
        ("page/page_client.v", "PageClient", "page_did_request_all_cookies_cookiestore"),
        ("page/page_client.v", "PageClient", "page_did_request_named_cookie"),
        ("page/page_client.v", "PageClient", "page_did_request_cookie"),
        ("page/page_client.v", "PageClient", "page_did_request_storage_item"),
        ("page/page_client.v", "PageClient", "page_did_request_storage_keys"),
        ("page/page_client.v", "PageClient", "page_did_request_new_web_view"),
        ("page/page_client.v", "PageClient", "request_worker_agent"),
        ("page/page_client.v", "PageClient", "is_svg_page_client"),
        # DOM collection/range binding hooks and compatibility no-ops.
        ("dom/collections_ranges.v", None, "always_accept_node"),
        ("dom/collections_ranges.v", None, "always_accept_element"),
        ("dom/collections_ranges.v", None, "never_sort_elements"),
        ("dom/collections_ranges.v", "NodeList", "initialize"),
        ("dom/collections_ranges.v", "HTMLCollection", "initialize"),
        ("dom/collections_ranges.v", "HTMLAllCollection", "is_htmldda"),
        ("dom/collections_ranges.v", "NamedNodeMap", "initialize"),
        ("dom/collections_ranges.v", "DOMTokenList", "initialize"),
        ("dom/collections_ranges.v", "NodeIterator", "initialize"),
        ("dom/collections_ranges.v", "NodeIterator", "detach"),
        ("dom/collections_ranges.v", "TreeWalker", "initialize"),
        ("dom/collections_ranges.v", "AbstractRange", "initialize"),
        ("dom/collections_ranges.v", "StaticRange", "initialize"),
        ("dom/collections_ranges.v", "Range", "initialize"),
        ("dom/collections_ranges.v", "Range", "detach"),
        # Location/WindowProxy exotic internal methods and Window identity hooks.
        ("html/window_context.v", "LocationModel", "is_html_location"),
        ("html/window_context.v", "LocationModel", "internal_is_extensible"),
        ("html/window_context.v", "LocationModel", "internal_prevent_extensions"),
        (
            "html/window_context.v",
            "BrowsingContextModel",
            "the_one_permitted_sandboxed_navigator",
        ),
        (
            "html/window_context.v",
            "BrowsingContextModel",
            "set_the_one_permitted_sandboxed_navigator",
        ),
        ("html/window_context.v", "WindowProxyModel", "is_universal_global_scope_mixin"),
        ("html/window_context.v", "WindowProxyModel", "is_html_window_proxy"),
        ("html/window_context.v", "WindowProxyModel", "is_extensible"),
        ("html/window_context.v", "WindowProxyModel", "prevent_extensions"),
        ("html/window_context.v", "WindowProxyModel", "internal_is_extensible"),
        ("html/window_context.v", "WindowProxyModel", "internal_prevent_extensions"),
        ("html/window_context.v", "WindowModel", "is_universal_global_scope_mixin"),
        ("html/window_context.v", "WindowModel", "is_html_window"),
        ("html/window_context.v", "WindowModel", "blur"),
        # Screen orientation and animation constructors/identity hooks mirror
        # the current upstream defaults; initialize is binding-only.
        ("css/screen_animation.v", "Screen", "create"),
        ("css/screen_animation.v", "ScreenOrientation", "create"),
        ("css/screen_animation.v", "ScreenOrientation", "unlock"),
        ("css/screen_animation.v", "ScreenOrientation", "angle"),
        ("css/screen_animation.v", "KeyframeEffect", "create"),
        ("css/screen_animation.v", "CSSAnimation", "is_css_animation"),
        ("css/screen_animation.v", "CSSTransition", "initialize"),
        ("css/screen_animation.v", "CSSTransition", "is_css_transition"),
        # Font collection construction and JS-set notification are exact; the
        # remaining entries are the deliberate no-platform-plugin fallbacks.
        ("css/font_face_values.v", "FontFaceSet", "on_set_modified_from_js"),
        ("css/font_face_values.v", "FontCascadeList", "create"),
        ("css/font_face_values.v", None, "platform_load_font_from_url_boundary"),
        ("css/font_face_values.v", None, "platform_load_font_from_bytes_boundary"),
        ("css/font_face_values.v", None, "platform_symbol_font_names_boundary"),
        ("css/font_face_values.v", None, "platform_typefaces_with_family_name_boundary"),
        # Stateless WebCrypto algorithm factories only allocate their concrete
        # dispatch object upstream. Null key lengths are represented by value:none.
        ("webcrypto/crypto_protocol.v", "AlgorithmParams", "from_value"),
        ("webcrypto/crypto_protocol.v", "AlgorithmMethods", "create"),
        ("webcrypto/key_algorithms.v", "KeyAlgorithm", "create"),
        ("webcrypto/key_algorithms.v", "RsaKeyAlgorithm", "create"),
        ("webcrypto/key_algorithms.v", "RsaHashedKeyAlgorithm", "create"),
        ("webcrypto/key_algorithms.v", "EcKeyAlgorithm", "create"),
        ("webcrypto/key_algorithms.v", "AesKeyAlgorithm", "create"),
        ("webcrypto/key_algorithms.v", "HmacKeyAlgorithm", "create"),
        ("webcrypto/key_algorithms.v", "KmacKeyAlgorithm", "create"),
        ("webcrypto/subtle_crypto.v", "SubtleCrypto", "create"),
        ("webcrypto/upstream_algorithm_classes.v", "AesCbc", "create"),
        ("webcrypto/upstream_algorithm_classes.v", "AesCtr", "create"),
        ("webcrypto/upstream_algorithm_classes.v", "AesGcm", "create"),
        ("webcrypto/upstream_algorithm_classes.v", "AesKw", "create"),
        ("webcrypto/upstream_algorithm_classes.v", "ChaCha20Poly1305", "create"),
        ("webcrypto/upstream_algorithm_classes.v", "SHA", "create"),
        ("webcrypto/upstream_algorithm_classes.v", "HMAC", "create"),
        ("webcrypto/upstream_algorithm_classes.v", "ED25519", "create"),
        ("webcrypto/upstream_algorithm_classes.v", "HKDF", "create"),
        ("webcrypto/upstream_algorithm_classes.v", "HKDF", "get_key_length"),
        ("webcrypto/upstream_algorithm_classes.v", "PBKDF2", "create"),
        ("webcrypto/upstream_algorithm_classes.v", "PBKDF2", "get_key_length"),
        ("webcrypto/upstream_algorithm_classes.v", "Argon2", "create"),
        ("webcrypto/upstream_algorithm_classes.v", "Argon2", "get_key_length"),
        ("webcrypto/upstream_algorithm_classes.v", "RSAOAEP", "create"),
        ("webcrypto/upstream_algorithm_classes.v", "RSAPSS", "create"),
        ("webcrypto/upstream_algorithm_classes.v", "RSASSAPKCS1", "create"),
        ("webcrypto/upstream_algorithm_classes.v", "ECDSA", "create"),
        ("webcrypto/upstream_algorithm_classes.v", "ECDH", "create"),
        ("webcrypto/upstream_algorithm_classes.v", "X25519", "create"),
        ("webcrypto/upstream_algorithm_classes.v", "X448", "create"),
        ("webcrypto/upstream_algorithm_classes.v", "ED448", "create"),
        ("webcrypto/upstream_algorithm_classes.v", "MLDSA", "create"),
        ("webcrypto/upstream_algorithm_classes.v", "MLKEM", "create"),
        ("webcrypto/upstream_algorithm_classes.v", "KMAC", "create"),
        ("webcrypto/upstream_algorithm_classes.v", "CShake", "create"),
        ("webcrypto/upstream_algorithm_classes.v", "AesOcb", "create"),
        # Empty CSS value factories construct meaningful default-state records.
        ("css/computed_interpolation.v", "GapValue", "normal"),
        ("css/computed_interpolation.v", "TouchActionData", "auto_"),
        ("css/computed_interpolation.v", "WillChange", "make_auto"),
        ("css/computed_interpolation.v", "InvalidationPlan", "create"),
        # Speech objects have no constructor state beyond their upstream realm.
        ("speech/grammar_and_results.v", "SpeechGrammar", "construct_impl"),
        ("speech/grammar_and_results.v", "SpeechGrammarList", "construct_impl"),
        ("speech/grammar_and_results.v", "SpeechRecognitionAlternative", "create"),
        ("speech/grammar_and_results.v", "SpeechRecognitionResult", "create"),
        ("speech/grammar_and_results.v", "SpeechRecognitionResultList", "create"),
        # Streams' zero values are the specified undefined/pending/unaborted states.
        ("streams/types.v", None, "undefined_value"),
        ("streams/types.v", "VoidPromise", "pending"),
        ("streams/types.v", "ReadPromise", "pending"),
        ("streams/types.v", "BYOBReadPromise", "pending"),
        ("streams/types.v", "AbortSignal", "create"),
        # These obsolete Document methods explicitly do nothing upstream.
        ("dom/document.v", "Document", "clear"),
        ("dom/document.v", "Document", "capture_events"),
        ("dom/document.v", "Document", "release_events"),
        # HTMLMediaElement's identity/focus overrides are literal true values;
        # the local callbacks are intentionally empty defaults replaced by tracks.
        ("html/html_media_element.v", None, "media_element_noop_change_task"),
        ("html/html_media_element.v", None, "media_element_noop_audio_enabled"),
        ("html/html_media_element.v", None, "media_element_noop_video_selected"),
        ("html/html_media_element.v", "HTMLMediaElement", "is_focusable"),
        ("html/html_media_element.v", "HTMLMediaElement", "is_html_media_element"),
        # Animation timeline capability and identity methods are literal
        # constants upstream. Optional-none is the upstream unresolved duration.
        ("animations/document_timeline.v", "DocumentTimeline", "duration"),
        (
            "animations/document_timeline.v",
            "DocumentTimeline",
            "can_convert_a_timeline_time_to_an_origin_relative_time",
        ),
        ("animations/keyframe_effect.v", "KeyframeEffect", "is_keyframe_effect"),
        ("animations/scroll_timeline.v", "ScrollTimeline", "is_progress_based"),
        (
            "animations/scroll_timeline.v",
            "ScrollTimeline",
            "can_convert_a_timeline_time_to_an_origin_relative_time",
        ),
        # These binding overrides are exact inline constants/defaults.
        ("bindings/audio_constructor.v", "AudioConstructor", "has_constructor"),
        ("bindings/image_constructor.v", "ImageConstructor", "has_constructor"),
        ("bindings/option_constructor.v", "OptionConstructor", "has_constructor"),
        (
            "bindings/platform_object.v",
            "PlatformObject",
            "eligible_for_own_property_enumeration_fast_path",
        ),
        ("bindings/platform_object.v", "PlatformObject", "extract_an_origin"),
        (
            "bindings/principal_host_defined.v",
            "PrincipalHostDefined",
            "is_principal_host_defined",
        ),
        (
            "bindings/synthetic_host_defined.v",
            "SyntheticHostDefined",
            "is_synthetic_host_defined",
        ),
        # CSSOM setters/defaults and the gradient predicates match upstream;
        # visit_edges and parse logging have no executable V-runtime work.
        ("css/cssom_events_extra.v", "CSSRule", "set_key_text"),
        ("css/cssom_rules.v", "CSSRule", "set_css_text"),
        ("css/descriptors.v", "CSSDescriptors", "get_property_priority"),
        ("css/image_color_values.v", "RadialGradientStyleValue", "is_paintable"),
        ("css/image_color_values.v", "ConicGradientStyleValue", "is_paintable"),
        ("css/parser_core.v", None, "log_parse_error"),
        ("css/parser_rules_selectors.v", None, "parser_log_parse_error"),
        ("css/properties_data.v", "CascadedProperties", "visit_edges"),
        ("css/selectors.v", None, "is_has_allowed_pseudo_element"),
        ("css/style_scope_cache.v", "MatchingRule", "visit_edges"),
        ("css/style_scope_cache.v", "RuleCache", "visit_edges"),
        ("css/syntax_highlighter.v", "SyntaxHighlighter", "is_navigatable"),
        # DOM binding/GC hooks and concrete type predicates are exact defaults.
        ("dom/document.v", "ViewportPaintable", "is_viewport_paintable"),
        ("dom/element.v", "CSSCountersSet_", "visit_edges"),
        ("dom/element.v", "Element", "initialize"),
        ("dom/node.v", "Node", "has_loaded_icon"),
        ("dom/node_inline_algorithms.v", "Node", "is_dom_node"),
        ("dom/ui_events.v", "UIEvent", "which"),
        ("dom/ui_events.v", "MouseEvent", "is_mouse_event"),
        ("dom/ui_events.v", "PointerEvent", "is_pointer_event"),
        # These EME checks and the legacy fullscreen unscopable flag are still
        # explicit constants in the current upstream implementation.
        ("encryptedmediaextensions/algorithms.v", None, "supports_container"),
        (
            "encryptedmediaextensions/key_system.v",
            "ClearKeySystem",
            "definitely_supports_playback",
        ),
        ("fullscreen/fullscreen.v", None, "document_fullscreen_is_unscopable"),
        # HTML type/focus/capability overrides below are literal constants in
        # their concrete upstream classes. Local callback bodies encode the
        # specified always/continue/no-action behavior at constructor sites.
        (
            "html/canvas_rendering_context_2d.v",
            "CanvasRenderingContext2D",
            "is_canvas_rendering_context_2d",
        ),
        ("html/close_watcher.v", None, "close_watcher_always_enabled"),
        ("html/close_watcher.v", None, "close_watcher_continue_cancel_action"),
        ("html/close_watcher.v", None, "close_watcher_empty_action"),
        ("html/decoded_image_data.v", "AnimatedDecodedImageData", "is_animated"),
        ("html/environments.v", "WorkerEnvironmentSettingsObject", "responsible_document"),
        ("html/external.v", "External", "add_search_provider"),
        ("html/external.v", "External", "is_search_provider_installed"),
        ("html/form_controls_collections.v", None, "form_collection_never_sort"),
        ("html/form_elements.v", "HTMLButtonElementModel", "default_tab_index_value"),
        ("html/form_elements.v", "HTMLButtonElementModel", "has_activation_behavior"),
        ("html/html_image_element.v", "HTMLImageElementModel", "is_html_image_element"),
        (
            "html/html_image_element.v",
            "HTMLImageElementModel",
            "supports_dimension_attributes",
        ),
        (
            "html/html_text_area_element.v",
            "HTMLTextAreaElementModel",
            "is_html_textarea_element",
        ),
        (
            "html/html_text_area_element.v",
            "HTMLTextAreaElementModel",
            "default_tab_index_value",
        ),
        ("html/interactive_elements.v", None, "html_dialog_element_is_focusable"),
        (
            "html/interactive_elements.v",
            None,
            "html_summary_element_has_activation_behavior",
        ),
        ("html/legacy_elements.v", "HTMLFrameElementModel", "default_tab_index_value"),
        ("html/legacy_elements.v", None, "html_frame_element_default_tab_index_value"),
        (
            "html/media_elements.v",
            "HTMLVideoElementModel",
            "supports_dimension_attributes",
        ),
        ("html/meter_progress_elements.v", None, "html_progress_element_is_labelable"),
        ("html/meter_progress_elements.v", None, "html_meter_element_is_labelable"),
        ("html/navigator_id.v", "NavigatorIDMixin", "vendor_sub"),
        ("html/scripting_runtime.v", "Script", "is_script"),
        ("html/scripting_runtime.v", "ClassicScript", "is_classic_script"),
        ("html/scripting_runtime.v", "ModuleScript", "is_module_script"),
        (
            "html/scripting_runtime.v",
            "JavaScriptModuleScript",
            "is_javascript_module_script",
        ),
        ("html/shared_resource_request.v", "ImageRequest", "prepare_for_presentation"),
        (
            "html/serialized_environment_settings_object.v",
            "EnvironmentSettingsSnapshot",
            "responsible_document",
        ),
        ("html/syntax_highlighter.v", "HTMLSyntaxHighlighter", "is_identifier"),
        ("html/syntax_highlighter.v", "HTMLSyntaxHighlighter", "is_navigatable"),
        ("html/html_tokenizer.v", "HTMLTokenizer", "will_switch_to"),
        ("html/html_tokenizer.v", "HTMLTokenizer", "will_reconsume_in"),
        ("html/traversable_navigable.v", "TraversableNavigable", "is_traversable"),
        (
            "html/workers.v",
            "WorkerGlobalScope",
            "is_universal_global_scope_mixin",
        ),
        (
            "html/workers.v",
            "ShadowRealmGlobalScope",
            "is_universal_global_scope_mixin",
        ),
        # Remaining media/painting/timing constants are direct upstream bodies.
        (
            "mediasourceextensions/media_source.v",
            "MediaSource",
            "can_construct_in_dedicated_worker",
        ),
        ("notificationsapi/notification.v", "Notification", "max_actions"),
        ("painting/svg_painting.v", "SVGPaintable", "is_svg_paintable"),
        ("serviceworker/container.v", "ServiceWorkerContainer", "controller"),
        ("usertiming/user_timing.v", "PerformanceMark", "max_buffer_size"),
        ("usertiming/user_timing.v", "PerformanceMeasure", "max_buffer_size"),
        ("webaudio/audio_algorithms.v", "ConstantSourceNode", "number_of_inputs"),
        ("webaudio/audio_algorithms.v", "OscillatorNode", "number_of_inputs"),
        ("webaudio/audio_algorithms.v", "AudioBufferSourceNode", "number_of_inputs"),
        (
            "webaudio/audio_algorithms.v",
            "MediaElementAudioSourceNode",
            "number_of_inputs",
        ),
        ("webaudio/context.v", "AudioContext", "output_timestamp"),
        ("webdriver/action_algorithms.v", None, "dispatch_pause_action"),
        # These animation, clipboard, cookie-store, and credential constructors
        # translate the upstream allocation/default-state setup directly.
        ("animations/animation_effect.v", "AnimationEffect", "new"),
        ("animations/animation_timeline.v", "AnimationTimeline", "new"),
        ("clipboard/clipboard.v", "ClipboardReadPromise", "pending"),
        ("clipboard/clipboard.v", "ClipboardTextPromise", "pending"),
        ("clipboard/clipboard.v", "ClipboardVoidPromise", "pending"),
        ("clipboard/clipboard_item.v", "ClipboardItemDataPromise", "pending"),
        ("clipboard/clipboard_item.v", "ClipboardBlobPromise", "pending"),
        ("clipboard/clipboard_item.v", "ClipboardItem", "create_empty"),
        ("clipboard/system_clipboard.v", "SystemClipboardBackend", "create"),
        ("cookiestore/cookie_backend.v", "CookieStoreBackend", "create"),
        ("cookiestore/cookie_store.v", "CookieItemPromise", "pending"),
        ("cookiestore/cookie_store.v", "CookieListPromise", "pending"),
        ("cookiestore/cookie_store.v", "CookieVoidPromise", "pending"),
        (
            "credentialmanagement/credentials_container.v",
            "CredentialsContainer",
            "construct_impl",
        ),
        # These CSS factories and sentinels have meaningful zero-value state.
        # The style-scope boundary mutates the same reference stored in its map,
        # so the upstream insert-or-assign step has no separate V operation.
        (
            "css/computed_interpolation.v",
            None,
            "computed_interpolation_empty_style_value",
        ),
        ("css/computed_values.v", "InitialValues", "column_count"),
        ("css/css.v", "Number", "new"),
        ("css/css.v", "LengthOrAuto", "make_auto"),
        ("css/css.v", "LengthPercentageOrAuto", "make_auto"),
        ("css/descriptors.v", "CSSDescriptors", "update_style_attribute"),
        ("css/grid_values.v", "GridTrackSizeList", "make_none"),
        ("css/misc_values.v", "Filter", "make_none"),
        ("css/more_style_values.v", "FitContentStyleValue", "create"),
        (
            "css/style_declarations.v",
            None,
            "css_style_properties_empty_dom_style_value",
        ),
        ("css/style_scope_cache.v", None, "style_scope_store_has_result_cache_boundary"),
        ("css/style_values_core.v", "NumericType", "new"),
        ("css/syntax_highlighter.v", "SyntaxHighlighter", "create"),
        ("css/transforms.v", "FloatMatrix4x4", "identity"),
        ("css/transforms.v", "DOMMatrix", "create"),
        # Collection, promise, and unique-ID defaults translate upstream state;
        # pointer-backed V node IDs have no separate directory to release from.
        ("dom/collections_ranges.v", "NodeList", "new"),
        ("dom/collections_ranges.v", "HTMLCollection", "empty"),
        ("dom/document.v", "Promise", "create"),
        ("dom/node.v", None, "deallocate_unique_id"),
        # The flat editing model has no transparent wrapper positions, so it has
        # no distinct next or previous equivalent boundary point to return.
        ("editing/upstream_algorithms.v", None, "next_equivalent_point"),
        ("editing/upstream_algorithms.v", None, "previous_equivalent_point"),
        # Binding constructors below allocate records whose V field defaults
        # carry the same initial state as their current upstream counterparts.
        ("encoding/text_encoder.v", "TextEncoder", "construct_impl"),
        ("encoding/text_encoder_stream.v", "TextEncoderStream", "construct_impl"),
        ("fetch/runtime.v", "FetchController", "create"),
        ("fetch/runtime.v", "FetchTimingInfo", "create"),
        ("fetch/runtime.v", "FetchRecord", "finalize"),
        ("fetch/runtime_operations.v", "FetchControllerHolder", "create"),
        ("fileapi/blob_url_store.v", "BlobURLStore", "create"),
        ("fileapi/file_reader.v", "FileReader", "create"),
        ("fileapi/file_reader.v", "FileReaderSync", "create"),
        ("fileapi/filelist.v", "FileList", "create"),
        # LegacyLenientSetter fullscreen assignments are specified no-ops.
        ("fullscreen/fullscreen.v", None, "set_document_fullscreen_enabled"),
        ("fullscreen/fullscreen.v", None, "set_document_fullscreen"),
        ("gamepad/navigator_gamepad.v", "NavigatorGamepadPartial", "new"),
        # Geometry create() is the internal empty-object deserialization path;
        # zero-valued coordinates and dimensions are its required initial state.
        ("geometry/dom_point.v", "DOMPointReadOnly", "create"),
        ("geometry/dom_point.v", "DOMPoint", "create"),
        ("geometry/dom_rect.v", "DOMRectReadOnly", "create"),
        ("geometry/dom_rect.v", "DOMRect", "create"),
        # These HTML hooks are allocation, embedding-boundary, base-class, or
        # explicitly implementation-defined no-op behavior upstream.
        ("html/canvas_inline_mixins.v", "CanvasTransform", "flush_transform"),
        ("html/canvas_path.v", "CanvasPath", "create"),
        ("html/canvas_rendering_algorithms.v", None, "image_is_not_origin_clean"),
        ("html/drag_data_store.v", "DragDataStore", "create"),
        ("html/event_loop.v", "ParallelQueue", "create"),
        ("html/external.v", "External", "create"),
        ("html/focus.v", "FocusManager", "create"),
        (
            "html/form_associated_element.v",
            "FormAssociatedElement",
            "form_associated_element_was_inserted",
        ),
        (
            "html/form_associated_element.v",
            "FormAssociatedElement",
            "form_associated_element_was_removed",
        ),
        (
            "html/form_associated_element.v",
            "FormAssociatedElement",
            "form_associated_element_was_moved",
        ),
        (
            "html/form_associated_element.v",
            "FormAssociatedElement",
            "form_associated_element_attribute_changed",
        ),
        ("html/image_bitmap.v", "ImageBitmap", "create"),
        ("html/import_map.v", None, "ignore_import_map_warning"),
        ("html/navigable.v", None, "navigable_noop_presentation_callback"),
        ("html/navigation_objects.v", "NavigationDestination", "create"),
        ("html/navigator.v", "WorkerNavigator", "create"),
        ("html/path2d.v", "Path2D", "create"),
        ("html/select_item.v", None, "encode_select_item_separator"),
        ("html/storage_history.v", "StorageHub", "create"),
        ("html/storage_history.v", "Storage", "reorder"),
        ("html/syntax_highlighter.v", "HTMLSyntaxHighlighter", "create"),
        ("html/text_metrics.v", "TextMetrics", "create"),
        ("html/xml_serializer.v", "XMLSerializer", "construct_impl"),
        ("http/header_list.v", "HeaderList", "create"),
        # IndexedDB delegates queue state to DatabaseData; the remaining
        # internal/internals entries translate allocation or exact defaults.
        ("indexeddb/internal_operations.v", "ConnectionQueueHandler", "the"),
        ("indexeddb/internal_operations.v", "MutationLog", "create"),
        (
            "internals/internal_animation_timeline.v",
            "InternalAnimationTimeline",
            "update_current_time",
        ),
        (
            "internals/internal_animation_timeline.v",
            "InternalAnimationTimeline",
            "duration",
        ),
        ("internals/xr_testing.v", "FakeXRDevice", "create"),
        ("internals/xr_testing.v", "XRTest", "create"),
        # Layout and loader entries translate default state or platform
        # boundaries whose upstream result is represented by that state.
        ("layout/block_flow_minimal.v", None, "solid_box_border_styles"),
        ("layout/layout_state.v", "LayoutState", "new"),
        ("loader/content_filter.v", "ContentFilter", "create"),
        ("loader/proxy_mappings.v", "ProxyMappings", "create"),
        (
            "mediasourceextensions/media_source.v",
            "MediaSourceHandle",
            "create_internal",
        ),
        ("page/page_client.v", "PageClient", "create"),
        ("page/page_entry_points.v", "Page", "pdf_viewer_supported"),
        # ResizeHandle enter/leave are empty virtual overrides upstream.
        ("painting/scrolling.v", "ResizeHandle", "create"),
        ("painting/scrolling.v", "ResizeHandle", "mouse_enter"),
        ("painting/scrolling.v", "ResizeHandle", "mouse_leave"),
        ("permissionspolicy/autoplay_allowlist.v", "AutoplayAllowlist", "new"),
        ("platform/event_loop_plugin.v", "EventLoopPlugin", "new"),
        ("platform/timer.v", "Timer", "create"),
        ("serviceworker/registration.v", "RegistrationStore", "create"),
        ("speech/synthesis.v", "SpeechSynthesisVoice", "create"),
        ("storageapi/storage_models.v", "StorageShed", "create"),
        ("storageapi/storage_models.v", "StorageManager", "create"),
        # Stream release steps return immediately upstream; the no-op algorithms
        # are intentional callback implementations used by the stream machinery.
        ("streams/pipe_tee_transfer.v", "MessagePort", "create"),
        (
            "streams/readable_controller_operations.v",
            "ReadableStreamDefaultController",
            "release_steps",
        ),
        ("streams/readable_controller_operations.v", None, "no_op_start_algorithm"),
        ("streams/readable_controller_operations.v", None, "no_op_pull_algorithm"),
        ("streams/readable_controller_operations.v", None, "no_op_cancel_algorithm"),
        ("streams/writable_operations.v", None, "no_op_write_algorithm"),
        ("streams/writable_operations.v", None, "no_op_close_algorithm"),
        ("streams/writable_operations.v", None, "no_op_abort_algorithm"),
        # These SVG methods remain explicit constants/no-ops in current
        # upstream: GaussianBlur edge mode, the text origin FIXME, and the
        # standalone decoded-image PageClient embedding defaults.
        ("svg/element_operations.v", "Element", "edge_mode"),
        ("svg/element_operations.v", "Element", "get_start_position_of_char"),
        ("svg/specialized_operations.v", "SVGPageClient", "is_svg_page_client"),
        ("svg/specialized_operations.v", "SVGPageClient", "is_connection_open"),
        ("svg/specialized_operations.v", "SVGPageClient", "screen_rect"),
        (
            "svg/specialized_operations.v",
            "SVGPageClient",
            "report_finished_handling_input_event",
        ),
        ("svg/specialized_operations.v", "SVGPageClient", "request_file"),
        # Remaining entries are stateless factories or exact lifecycle/default
        # hooks whose upstream realm/GC state has no distinct V representation.
        ("trustedtypes/factory_csp.v", "TrustedTypePolicyFactory", "create"),
        ("urlpattern/pattern_types.v", None, "default_pattern_options"),
        ("webdriver/client_execute_entry_points.v", "Client", "new"),
        ("webidl/observable_array.v", "ObservableArray", "create"),
        ("webvtt/vtt_region.v", "VTTRegion", "construct_impl"),
        ("webxr/webxr.v", "XRSystem", "create"),
        ("worker/web_worker_client.v", "WebWorkerClient", "die"),
        ("xpath/evaluator.v", "XPathEvaluator", "construct"),
        # These remain explicit upstream defaults: SVGGraphicsElement returns
        # new identity DOMMatrix objects, non-fetch navigation returns null,
        # and SVGImageElement's visibility hook is an empty override.
        ("html/navigable.v", None, "attempt_to_create_a_non_fetch_scheme_document"),
        ("svg/element_operations.v", "Element", "get_ctm"),
        ("svg/element_operations.v", "Element", "get_screen_ctm"),
        ("svg/element_operations.v", "Element", "set_visible_in_viewport"),
        # SourceLocation cannot capture a V caller through a normal function;
        # current_at preserves explicit sites. MediaSourceHandle's marker and
        # EGL configuration are standalone runtime/platform-boundary behavior.
        ("html/source_location.v", "SourceLocation", "current"),
        (
            "mediasourceextensions/media_source.v",
            "MediaSourceHandle",
            "is_transferable",
        ),
        ("webgl/native_context_operations.v", None, "get_egl_config"),
    }
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--ladybird",
        type=Path,
        default=Path.home() / "code/3rd/ladybird",
        help="Ladybird checkout containing Libraries/LibWeb",
    )
    parser.add_argument(
        "--translation",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="libweb_v checkout",
    )
    parser.add_argument("--json", action="store_true", help="emit the complete inventory as JSON")
    return parser.parse_args()


def is_unreviewed_coverage_shim(source: Path) -> bool:
    return any(fnmatch.fnmatch(source.name, pattern) for pattern in UNREVIEWED_COVERAGE_SHIMS)


def all_v_function_names(
    translation: Path,
) -> tuple[set[tuple[str, str | None]], list[str], int]:
    functions: set[tuple[str, str | None]] = set()
    quarantined_files: list[str] = []
    quarantined_functions = 0
    for source in translation.rglob("*.v"):
        if source.name.endswith("_test.v"):
            continue
        if any(part in EXCLUDED_TRANSLATION_DIRECTORIES for part in source.parts):
            continue
        text = source.read_text(errors="replace")
        if is_unreviewed_coverage_shim(source):
            quarantined_files.append(source.relative_to(translation).as_posix())
            quarantined_functions += len(list(html_audit.V_FUNCTION.finditer(text)))
            continue
        for match in html_audit.V_FUNCTION.finditer(text):
            owner = match.group("associated")
            if receiver := match.group("receiver"):
                receiver_type = receiver.split()[-1].lstrip("&?")
                owner = receiver_type.split(".")[-1]
            # Boundary placeholders are not implementations of upstream
            # methods, even when their names happen to match.
            if owner and (owner.endswith("Facade") or owner.endswith("Stub")):
                continue
            functions.add((match.group("name"), owner))
        for interface in html_audit.V_INTERFACE.finditer(text):
            owner = interface.group("name")
            for method in html_audit.V_INTERFACE_METHOD.finditer(interface.group("body")):
                functions.add((method.group("name"), owner))
    return functions, sorted(quarantined_files), quarantined_functions


def all_v_field_names(translation: Path) -> set[tuple[str, str]]:
    fields: set[tuple[str, str]] = set()
    for source in translation.rglob("*.v"):
        if source.name.endswith("_test.v") or is_unreviewed_coverage_shim(source):
            continue
        if any(part in EXCLUDED_TRANSLATION_DIRECTORIES for part in source.parts):
            continue
        fields.update(html_audit.v_field_names_in_text(source.read_text(errors="replace")))
    return fields


def semantic_divergence_inventory(translation: Path) -> list[dict[str, object]]:
    markers: list[dict[str, object]] = []
    for source in sorted(translation.rglob("*.v")):
        if source.name.endswith("_test.v"):
            continue
        if any(part in EXCLUDED_TRANSLATION_DIRECTORIES for part in source.parts):
            continue
        for line_number, line in enumerate(source.read_text(errors="replace").splitlines(), 1):
            if any(pattern.search(line) for pattern in SEMANTIC_DIVERGENCE_MARKERS):
                markers.append(
                    {
                        "source": source.relative_to(translation).as_posix(),
                        "line": line_number,
                        "text": line.strip(),
                    }
                )
    return markers


def _skip_v_quoted_or_commented(text: str, index: int) -> int | None:
    if text.startswith("//", index):
        newline = text.find("\n", index + 2)
        return len(text) if newline < 0 else newline + 1
    if text.startswith("/*", index):
        end = text.find("*/", index + 2)
        return len(text) if end < 0 else end + 2
    quote = text[index]
    if quote not in "'\"`":
        return None
    index += 1
    while index < len(text):
        if text[index] == "\\" and quote != "`":
            index += 2
            continue
        if text[index] == quote:
            return index + 1
        index += 1
    return len(text)


def _v_function_body(text: str, function: re.Match[str]) -> tuple[int, int] | None:
    # V_FUNCTION ends immediately after the opening parameter parenthesis.
    # Find its mate first so braces inside default expressions cannot be
    # mistaken for the implementation body.
    index = function.end()
    parentheses = 1
    while index < len(text) and parentheses:
        skipped = _skip_v_quoted_or_commented(text, index)
        if skipped is not None:
            index = skipped
            continue
        if text[index] == "(":
            parentheses += 1
        elif text[index] == ")":
            parentheses -= 1
        index += 1
    while index < len(text):
        skipped = _skip_v_quoted_or_commented(text, index)
        if skipped is not None:
            index = skipped
            continue
        if text[index] == "{":
            break
        # A declaration-only function type/interface is not an implementation.
        if text[index] == "\n" and text[index + 1 :].lstrip().startswith("fn "):
            return None
        index += 1
    if index >= len(text):
        return None
    body_start = index + 1
    braces = 1
    index += 1
    while index < len(text) and braces:
        skipped = _skip_v_quoted_or_commented(text, index)
        if skipped is not None:
            index = skipped
            continue
        if text[index] == "{":
            braces += 1
        elif text[index] == "}":
            braces -= 1
        index += 1
    if braces:
        return None
    return body_start, index - 1


def trivial_implementation_inventories(
    translation: Path,
) -> tuple[list[dict[str, object]], list[dict[str, object]]]:
    """Find silent empty/default-return bodies that name coverage misses.

    This is intentionally an investigation queue, not an automatic assertion
    of divergence: some upstream methods are legitimately constant or no-op.
    Each result must still be compared with the corresponding C++ body. Exact
    matches already reviewed that way are returned separately.
    """
    findings: list[dict[str, object]] = []
    verified: list[dict[str, object]] = []
    for source in sorted(translation.rglob("*.v")):
        if source.name.endswith("_test.v") or is_unreviewed_coverage_shim(source):
            continue
        if any(part in EXCLUDED_TRANSLATION_DIRECTORIES for part in source.parts):
            continue
        text = source.read_text(errors="replace")
        for function in html_audit.V_FUNCTION.finditer(text):
            bounds = _v_function_body(text, function)
            if bounds is None:
                continue
            body_start, body_end = bounds
            body = text[body_start:body_end]
            body = re.sub(r"/\*.*?\*/", "", body, flags=re.DOTALL)
            body = re.sub(r"//[^\n]*", "", body)
            statements = []
            for statement in body.splitlines():
                stripped = statement.strip().rstrip(";")
                if not stripped:
                    continue
                if stripped.startswith("_ = "):
                    # Ignore V's unused-parameter suppression, but retain an
                    # intentionally discarded call result. The latter is a
                    # real delegated implementation (for example the public
                    # StyleInvalidationData builder wrapper), not an empty body.
                    discarded_expression = stripped[4:].strip()
                    if re.fullmatch(r"[A-Za-z_]\w*", discarded_expression):
                        continue
                statements.append(stripped)
            if statements and not (len(statements) == 1 and TRIVIAL_RETURN.fullmatch(statements[0])):
                continue
            owner = function.group("associated")
            if receiver := function.group("receiver"):
                receiver_type = receiver.split()[-1].lstrip("&?")
                owner = receiver_type.split(".")[-1]
            line = text.count("\n", 0, function.start()) + 1
            finding = {
                "source": source.relative_to(translation).as_posix(),
                "line": line,
                "owner": owner,
                "name": function.group("name"),
                "body": "\n".join(statements),
            }
            key = (finding["source"], owner, finding["name"])
            if key in VERIFIED_TRIVIAL_IMPLEMENTATIONS:
                verified.append(finding)
            else:
                findings.append(finding)
    return findings, verified


def suspicious_trivial_implementation_inventory(translation: Path) -> list[dict[str, object]]:
    return trivial_implementation_inventories(translation)[0]


def module_inventory(
    upstream_module: Path,
    functions: set[tuple[str, str | None]],
    fields: set[tuple[str, str]] | None = None,
) -> list[html_audit.UpstreamMethod]:
    inventory = html_audit.method_inventory(upstream_module, functions, fields)
    inventory.extend(html_audit.header_inline_inventory(upstream_module, functions, fields))
    inventory.extend(html_audit.free_function_inventory(upstream_module, functions))
    inventory.extend(html_audit.qualified_header_template_inventory(upstream_module))
    inventory.sort(key=lambda method: (method.source, method.line, method.class_name, method.name))
    return inventory


def main() -> int:
    args = parse_args()
    upstream_root = args.ladybird / "Libraries/LibWeb"
    if not upstream_root.is_dir():
        raise SystemExit(f"upstream LibWeb directory does not exist: {upstream_root}")

    functions, quarantined_files, quarantined_functions = all_v_function_names(args.translation)
    fields = all_v_field_names(args.translation)
    semantic_markers = semantic_divergence_inventory(args.translation)
    suspicious_trivial_implementations, verified_trivial_implementations = (
        trivial_implementation_inventories(args.translation)
    )
    modules: dict[str, dict[str, object]] = {}
    all_methods: list[dict[str, object]] = []
    total_dispositions: collections.Counter[str] = collections.Counter()
    total_cpp_files = 0

    for upstream_module in sorted(path for path in upstream_root.iterdir() if path.is_dir()):
        cpp_files = len(list(upstream_module.rglob("*.cpp")))
        if cpp_files == 0:
            continue
        inventory = module_inventory(upstream_module, functions, fields)
        dispositions = collections.Counter(method.disposition for method in inventory)
        unmatched_by_class = collections.Counter(
            method.class_name for method in inventory if method.disposition == "unmatched"
        )
        modules[upstream_module.name] = {
            "cpp_files": cpp_files,
            "functions": len(inventory),
            "dispositions": dict(sorted(dispositions.items())),
            "unmatched_by_class": dict(unmatched_by_class.most_common()),
        }
        total_cpp_files += cpp_files
        total_dispositions.update(dispositions)
        all_methods.extend(
            {
                "module": upstream_module.name,
                **asdict(method),
            }
            for method in inventory
        )

    payload = {
        "upstream_modules": len(modules),
        "upstream_cpp_files": total_cpp_files,
        "upstream_functions": len(all_methods),
        "v_function_names": len(functions),
        "quarantined_coverage_shim_files": quarantined_files,
        "quarantined_coverage_shim_functions": quarantined_functions,
        "semantic_divergence_markers": semantic_markers,
        "verified_trivial_implementations": verified_trivial_implementations,
        "suspicious_trivial_implementations": suspicious_trivial_implementations,
        "dispositions": dict(sorted(total_dispositions.items())),
        "modules": modules,
        "methods": all_methods,
    }
    if args.json:
        print(json.dumps(payload, indent=2))
    else:
        print(f"upstream modules: {payload['upstream_modules']}")
        print(f"upstream .cpp files: {payload['upstream_cpp_files']}")
        print(f"upstream implementations: {payload['upstream_functions']}")
        print(
            "quarantined name-only coverage shims: "
            f"{len(quarantined_files)} files / {quarantined_functions} functions"
        )
        print(f"explicit semantic-divergence markers: {len(semantic_markers)}")
        print(f"reviewed upstream-equivalent trivial implementations: {len(verified_trivial_implementations)}")
        print(
            "suspicious empty/default-return implementations: "
            f"{len(suspicious_trivial_implementations)}"
        )
        for disposition, count in total_dispositions.most_common():
            print(f"  {disposition}: {count}")
        print("unmatched implementations by module:")
        for module_name, module in modules.items():
            unmatched = module["dispositions"].get("unmatched", 0)
            if unmatched:
                print(f"  {unmatched:5} {module_name}")
    return 1 if total_dispositions["unmatched"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
