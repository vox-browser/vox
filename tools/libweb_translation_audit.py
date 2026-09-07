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
        # NavigationTiming/PerformanceTiming.h defines these legacy getters as zero.
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
) -> list[html_audit.UpstreamMethod]:
    inventory = html_audit.method_inventory(upstream_module, functions)
    inventory.extend(html_audit.header_inline_inventory(upstream_module, functions))
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
        inventory = module_inventory(upstream_module, functions)
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
