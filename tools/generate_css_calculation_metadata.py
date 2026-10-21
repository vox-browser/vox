#!/usr/bin/env python3
"""Translate Ladybird's generated CSS property metadata to V.

The C++ PropertyID generator derives these tables from Properties.json and
Enums.json. Keeping the V tables generated from those same inputs prevents
property parsing, invalidation, multiplicity, and calculation semantics from
drifting from upstream.
"""

from __future__ import annotations

import argparse
import collections
import json
from collections import defaultdict
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--ladybird",
        type=Path,
        default=Path.home() / "code/3rd/ladybird",
    )
    parser.add_argument(
        "--translation",
        type=Path,
        default=Path(__file__).resolve().parents[1],
    )
    return parser.parse_args()


def v_property_name(name: str) -> str:
    if name == "-webkit-text-fill-color":
        return "webkit_text_fill_color"
    translated = name.replace("-", "_")
    if translated == "float":
        return "float_"
    return translated


def replace_logical_aliases(
    properties: dict[str, object], logical_property_groups: dict[str, object]
) -> dict[str, object]:
    """Mirror GenerateCSSPropertyID.cpp::replace_logical_aliases()."""
    expanded = dict(properties)
    first_property_in_group: dict[str, str] = {}
    for group_name, raw_group in logical_property_groups.items():
        if not isinstance(raw_group, dict) or not raw_group:
            raise SystemExit(f"invalid logical property group: {group_name}")
        physical_properties = raw_group.get("physical")
        if not isinstance(physical_properties, dict) or not physical_properties:
            raise SystemExit(f"logical property group has no physical properties: {group_name}")
        first_property_in_group[group_name] = str(next(iter(physical_properties.values())))

    for name, raw_property in properties.items():
        if not isinstance(raw_property, dict):
            continue
        logical_alias = raw_property.get("logical-alias-for")
        if not isinstance(logical_alias, dict):
            continue
        group_name = str(logical_alias.get("group", ""))
        physical_name = first_property_in_group.get(group_name)
        if physical_name is None:
            raise SystemExit(f"logical property group {group_name!r} not found for {name}")
        raw_physical = properties.get(physical_name)
        if not isinstance(raw_physical, dict):
            raise SystemExit(f"physical property {physical_name!r} not found for {name}")
        replacement = dict(raw_physical)
        replacement.update(raw_property)
        replacement.pop("quirks", None)
        expanded[name] = replacement
    return expanded


def populate_all_property_longhands(properties: dict[str, object]) -> dict[str, object]:
    """Mirror GenerateCSSPropertyID.cpp::populate_all_property_longhands()."""
    expanded = dict(properties)
    raw_all = properties.get("all")
    if not isinstance(raw_all, dict):
        raise SystemExit("CSS all property was not found")
    all_property = dict(raw_all)
    longhands = list(all_property.get("longhands", []))
    for name, raw_property in properties.items():
        if not isinstance(raw_property, dict):
            continue
        if (
            "longhands" in raw_property
            or raw_property.get("legacy-alias-for")
            or name in {"direction", "unicode-bidi"}
        ):
            continue
        longhands.append(name)
    all_property["longhands"] = longhands
    expanded["all"] = all_property
    return expanded


def v_limit(value: str) -> str:
    if value == "-∞":
        return "-math.max_f32"
    if value == "∞":
        return "math.max_f32"
    return value


def property_ranges(properties: dict[str, object]) -> dict[tuple[tuple[str, str, str], ...], list[str]]:
    groups: dict[tuple[tuple[str, str, str], ...], list[str]] = defaultdict(list)
    for name, raw_property in properties.items():
        if not isinstance(raw_property, dict) or raw_property.get("legacy-alias-for"):
            continue

        ranges: list[tuple[str, str, str]] = []
        for valid_type in raw_property.get("valid-types", []):
            if valid_type == "opacity":
                ranges.extend((("number", "0", "1"), ("percentage", "0", "100")))
                continue

            parts = valid_type.split()
            if len(parts) < 2 or parts[0] == "custom-ident":
                continue
            serialized_range = parts[1]
            if not serialized_range.startswith("[") or not serialized_range.endswith("]"):
                continue
            limits = serialized_range[1:-1].split(",")
            if len(limits) != 2:
                raise SystemExit(f"invalid range for {name}: {valid_type}")
            ranges.append((parts[0], v_limit(limits[0]), v_limit(limits[1])))

        if ranges:
            groups[tuple(ranges)].append(v_property_name(name))
    return groups


def percentage_groups(properties: dict[str, object]) -> dict[str, list[str]]:
    groups: dict[str, list[str]] = defaultdict(list)
    for name, raw_property in properties.items():
        if not isinstance(raw_property, dict) or raw_property.get("legacy-alias-for"):
            continue
        if resolved_type := raw_property.get("percentages-resolve-to"):
            groups[str(resolved_type)].append(v_property_name(name))
    return groups


def match_cases(properties: list[str]) -> str:
    return ", ".join(f".{name}" for name in properties)


def append_boolean_match(
    output: list[str], signature: str, properties: list[str]
) -> None:
    output.extend(
        (
            f"{signature} {{",
            "\treturn match property_id {",
            f"\t\t{match_cases(properties)} {{ true }}",
            "\t\telse { false }",
            "\t}",
            "}",
            "",
        )
    )


BOUND_CHECK_TYPES = {
    "angle": ("Angle", "value.raw_value()"),
    "flex": ("Flex", "value.raw_value()"),
    "frequency": ("Frequency", "value.raw_value()"),
    "integer": ("i64", "value"),
    "length": ("Length", "value.raw_value()"),
    "number": ("f64", "value"),
    "percentage": ("Percentage", "value.value()"),
    "resolution": ("Resolution", "value.raw_value()"),
    "time": ("Time", "value.raw_value()"),
}


def bound_check_groups(
    properties: dict[str, object], value_type: str
) -> dict[tuple[str | None, str | None], list[str]]:
    groups: dict[tuple[str | None, str | None], list[str]] = defaultdict(list)
    for name, raw_property in properties.items():
        if not isinstance(raw_property, dict) or raw_property.get("legacy-alias-for"):
            continue
        for valid_type in raw_property.get("valid-types", []):
            parts = valid_type.split()
            if not parts or parts[0] != value_type:
                continue
            minimum: str | None = None
            maximum: str | None = None
            if len(parts) > 1:
                serialized_range = parts[1]
                if not serialized_range.startswith("[") or not serialized_range.endswith("]"):
                    raise SystemExit(f"invalid range for {name}: {valid_type}")
                limits = serialized_range[1:-1].split(",")
                if len(limits) != 2:
                    raise SystemExit(f"invalid range for {name}: {valid_type}")
                if limits[0] != "-∞":
                    minimum = limits[0]
                if limits[1] != "∞":
                    maximum = limits[1]
            groups[(minimum, maximum)].append(v_property_name(name))
            break
    return groups


def bound_check_expression(getter: str, minimum: str | None, maximum: str | None) -> str:
    checks: list[str] = []
    if minimum is not None:
        checks.append(f"{getter} >= {minimum}")
    if maximum is not None:
        checks.append(f"{getter} <= {maximum}")
    return " && ".join(checks) or "true"


def accepted_type_groups(
    properties: dict[str, object], enum_names: set[str]
) -> dict[tuple[str, ...], list[str]]:
    groups: dict[tuple[str, ...], list[str]] = defaultdict(list)
    for name, raw_property in properties.items():
        if not isinstance(raw_property, dict) or raw_property.get("legacy-alias-for"):
            continue
        accepted_types: list[str] = []
        for valid_type in raw_property.get("valid-types", []):
            value_type = valid_type.split()[0]
            if value_type in enum_names:
                continue
            accepted_types.append(value_type.replace("-", "_"))
        if accepted_types:
            groups[tuple(accepted_types)].append(v_property_name(name))
    return groups


def accepted_keyword_groups(
    properties: dict[str, object], enums: dict[str, list[str]]
) -> dict[tuple[str, ...], list[str]]:
    groups: dict[tuple[str, ...], list[str]] = defaultdict(list)
    for name, raw_property in properties.items():
        if not isinstance(raw_property, dict) or raw_property.get("legacy-alias-for"):
            continue
        keywords: list[str] = []
        for identifier in raw_property.get("valid-identifiers", []):
            # Upstream serializes legacy value aliases as `alias>canonical` and
            # accepts the alias keyword here before resolving it separately.
            keywords.append(str(identifier).split(">", 1)[0])
        for valid_type in raw_property.get("valid-types", []):
            value_type = valid_type.split()[0]
            keywords.extend(enums.get(value_type, []))
        unique_keywords = tuple(dict.fromkeys(keywords))
        if unique_keywords:
            groups[unique_keywords].append(v_property_name(name))
    return groups


def custom_ident_blacklist_groups(
    properties: dict[str, object]
) -> dict[tuple[str, ...], list[str]]:
    groups: dict[tuple[str, ...], list[str]] = defaultdict(list)
    for name, raw_property in properties.items():
        if not isinstance(raw_property, dict) or raw_property.get("legacy-alias-for"):
            continue
        for valid_type in raw_property.get("valid-types", []):
            parts = valid_type.split()
            if not parts or parts[0] != "custom-ident" or len(parts) == 1:
                continue
            if len(parts) != 2 or not parts[1].startswith("![") or not parts[1].endswith("]"):
                raise SystemExit(f"invalid custom-ident blacklist for {name}: {valid_type}")
            blacklist = tuple(parts[1][2:-1].split(","))
            groups[blacklist].append(v_property_name(name))
            break
    return groups


def legacy_alias_groups(properties: dict[str, object]) -> dict[str, list[str]]:
    groups: dict[str, list[str]] = defaultdict(list)
    for name, raw_property in properties.items():
        if isinstance(raw_property, dict) and raw_property.get("legacy-alias-for"):
            groups[str(raw_property["legacy-alias-for"])].append(name)
    return groups


def multiplicity_groups(properties: dict[str, object]) -> dict[str, list[str]]:
    groups: dict[str, list[str]] = defaultdict(list)
    for name, raw_property in properties.items():
        if not isinstance(raw_property, dict) or raw_property.get("legacy-alias-for"):
            continue
        multiplicity = str(raw_property.get("multiplicity", "single"))
        if multiplicity not in {"single", "list", "coordinating-list"}:
            raise SystemExit(f"invalid multiplicity for {name}: {multiplicity}")
        if multiplicity != "single":
            groups[multiplicity].append(v_property_name(name))
    return groups


def animation_type_groups(properties: dict[str, object]) -> dict[str, list[str]]:
    groups: dict[str, list[str]] = defaultdict(list)
    for name, raw_property in properties.items():
        if not isinstance(raw_property, dict) or raw_property.get("legacy-alias-for"):
            continue
        if "longhands" in raw_property:
            continue
        animation_type = raw_property.get("animation-type")
        if animation_type not in {
            "discrete",
            "by-computed-value",
            "repeatable-list",
            "custom",
            "none",
        }:
            raise SystemExit(f"invalid animation type for {name}: {animation_type}")
        groups[str(animation_type)].append(v_property_name(name))
    return groups


def property_is_animatable(
    properties: dict[str, object], property_name: str, visiting: set[str] | None = None
) -> bool:
    visiting = set() if visiting is None else visiting
    if property_name in visiting:
        raise SystemExit(f"recursive CSS shorthand: {property_name}")
    raw_property = properties.get(property_name)
    if not isinstance(raw_property, dict):
        raise SystemExit(f"CSS property not found: {property_name}")
    if animation_type := raw_property.get("animation-type"):
        return animation_type != "none"
    longhands = raw_property.get("longhands")
    if not isinstance(longhands, list):
        raise SystemExit(f"property must specify animation-type or longhands: {property_name}")
    next_visiting = visiting | {property_name}
    return any(
        property_is_animatable(properties, str(longhand), next_visiting)
        for longhand in longhands
    )


def boolean_metadata_properties(
    properties: dict[str, object], key: str, default: bool
) -> list[str]:
    result: list[str] = []
    for name, raw_property in properties.items():
        if not isinstance(raw_property, dict) or raw_property.get("legacy-alias-for"):
            continue
        if bool(raw_property.get(key, default)):
            result.append(v_property_name(name))
    return result


def quirk_groups(properties: dict[str, object]) -> dict[str, list[str]]:
    groups: dict[str, list[str]] = defaultdict(list)
    for name, raw_property in properties.items():
        if not isinstance(raw_property, dict) or raw_property.get("legacy-alias-for"):
            continue
        for quirk in raw_property.get("quirks", []):
            groups[str(quirk)].append(v_property_name(name))
    return groups


def computation_requirement_properties(
    properties: dict[str, object], accepted_requirements: set[str]
) -> list[str]:
    result: list[str] = []
    valid_requirements = {"always", "non-inherited-value", "cascaded-value", "never"}
    for name, raw_property in properties.items():
        if not isinstance(raw_property, dict) or raw_property.get("legacy-alias-for"):
            continue
        if "longhands" in raw_property:
            if "requires-computation" in raw_property:
                raise SystemExit(f"shorthand cannot require computation: {name}")
            continue
        requirement = raw_property.get("requires-computation")
        if requirement not in valid_requirements:
            raise SystemExit(f"invalid computation requirement for {name}: {requirement}")
        if str(requirement) in accepted_requirements:
            result.append(v_property_name(name))
    return result


def maximum_value_count_groups(properties: dict[str, object]) -> dict[int, list[str]]:
    groups: dict[int, list[str]] = defaultdict(list)
    for name, raw_property in properties.items():
        if not isinstance(raw_property, dict) or raw_property.get("legacy-alias-for"):
            continue
        maximum = int(raw_property.get("max-values", 1))
        if maximum != 1:
            groups[maximum].append(v_property_name(name))
    return groups


def legacy_value_aliases(properties: dict[str, object]) -> list[tuple[str, str, str]]:
    aliases: list[tuple[str, str, str]] = []
    for name, raw_property in properties.items():
        if not isinstance(raw_property, dict) or raw_property.get("legacy-alias-for"):
            continue
        for raw_identifier in raw_property.get("valid-identifiers", []):
            identifier = str(raw_identifier)
            if ">" not in identifier:
                continue
            from_keyword, to_keyword = identifier.split(">", 1)
            aliases.append((v_property_name(name), from_keyword, to_keyword))
    return aliases


def v_keyword_name(name: str) -> str:
    translated = name.replace("-", "_")
    if translated in {"none", "in", "is", "or"}:
        translated += "_"
    return translated



def dispatched_lookup(rows, name, result):
    rows = sorted(rows)
    if not rows:
        return '\treturn none\n'
    groups = collections.defaultdict(lambda: collections.defaultdict(list))
    for text, value in rows:
        assert text and text.isascii()
        groups[len(text)][ord(text[0])].append((text, value))
    lines = [f'\t// Keep bucket selection scalar; wrap the result once after a full match.',
             f'\tmut value := {result}.{rows[0][1]}',
             '\tmut found := false',
             f'\tmatch {name}.len {{']
    for length, prefixes in sorted(groups.items()):
        lines += [f'\t\t{length} {{', f'\t\t\tmatch {name}[0] {{']
        for prefix, entries in sorted(prefixes.items()):
            lines += [f'\t\t\t\t0x{prefix:02x} {{', f'\t\t\t\t\tmatch {name} {{']
            for text, value in entries:
                lines += [f"\t\t\t\t\t\t'{text}' {{",
                          f'\t\t\t\t\t\t\tvalue = {result}.{value}',
                          '\t\t\t\t\t\t\tfound = true',
                          '\t\t\t\t\t\t}']
            lines += ['\t\t\t\t\t\telse {}', '\t\t\t\t\t}', '\t\t\t\t}']
        lines += ['\t\t\t\telse {}', '\t\t\t}', '\t\t}']
    lines += ['\t\telse {}', '\t}', '\tif !found { return none }', '\treturn value']
    return '\n'.join(lines) + '\n'

def generate(properties: dict[str, object], enums: dict[str, list[str]]) -> str:
    enum_names = set(enums)
    output = [
        "// Generated from Ladybird Libraries/LibWeb/CSS/Properties.json,",
        "// LogicalPropertyGroups.json, and Enums.json by",
        "// tools/generate_css_calculation_metadata.py. Do not edit by hand.",
        "module css",
        "",
        "import math",
        "",
        "fn canonical_property_name_from_metadata(name string) string {",
        "\treturn match name {",
    ]
    for canonical_name, aliases in legacy_alias_groups(properties).items():
        serialized_aliases = ", ".join(repr(alias) for alias in aliases)
        output.extend(
            (
                f"\t\t{serialized_aliases} {{",
                f"\t\t\t{canonical_name!r}",
                "\t\t}",
            )
        )
    output.extend(("\t\telse { name }", "\t}", "}", ""))

    output.append("fn property_id_from_canonical_name(name string) ?PropertyID {")
    rows = [(name, v_property_name(name)) for name, raw_property in properties.items()
            if not (isinstance(raw_property, dict) and raw_property.get("legacy-alias-for"))]
    output.extend(dispatched_lookup(rows, 'name', 'PropertyID').splitlines())
    output.extend(("}", ""))

    output.extend(
        (
            "pub fn string_from_property_id(property_id PropertyID) string {",
            "\treturn match property_id {",
        )
    )
    for name, raw_property in properties.items():
        if isinstance(raw_property, dict) and raw_property.get("legacy-alias-for"):
            continue
        output.append(f"\t\t.{v_property_name(name)} {{ {name!r} }}")
    output.extend(("\t}", "}", ""))

    quirks = quirk_groups(properties)
    output.extend(
        (
            "pub enum PropertyQuirk {",
            "\thashless_hex_color",
            "\tunitless_length",
            "}",
            "",
            "pub fn property_has_quirk(property_id PropertyID, quirk PropertyQuirk) bool {",
            "\treturn match quirk {",
        )
    )
    for quirk_name in ("hashless-hex-color", "unitless-length"):
        output.extend(
            (
                f"\t\t.{quirk_name.replace('-', '_')} {{",
                "\t\t\tmatch property_id {",
                f"\t\t\t\t{match_cases(quirks.get(quirk_name, []))} {{ true }}",
                "\t\t\t\telse { false }",
                "\t\t\t}",
                "\t\t}",
            )
        )
    output.extend(("\t}", "}", ""))

    inherited_properties = [
        v_property_name(name)
        for name, raw_property in properties.items()
        if isinstance(raw_property, dict)
        and not raw_property.get("legacy-alias-for")
        and "longhands" not in raw_property
        and raw_property.get("inherited") is True
    ]
    append_boolean_match(
        output,
        "pub fn is_inherited_property(property_id PropertyID) bool",
        inherited_properties,
    )
    output.extend(
        (
            "pub fn property_initial_value_string(property_id PropertyID) string {",
            "\treturn match property_id {",
        )
    )
    for name, raw_property in properties.items():
        if not isinstance(raw_property, dict) or raw_property.get("legacy-alias-for"):
            continue
        initial_value = raw_property.get("initial")
        if not isinstance(initial_value, str):
            raise SystemExit(f"property is missing initial value: {name}")
        output.append(
            f"\t\t.{v_property_name(name)} {{ {initial_value!r} }}"
        )
    output.extend(("\t}", "}", ""))

    output.extend(
        (
            "fn animation_type_from_longhand_property(property_id PropertyID) AnimationType {",
            "\treturn match property_id {",
        )
    )
    for animation_type, properties_for_animation_type in animation_type_groups(properties).items():
        v_animation_type = animation_type.replace("-", "_")
        if v_animation_type == "none":
            v_animation_type = "none_"
        output.extend(
            (
                f"\t\t{match_cases(properties_for_animation_type)} {{",
                f"\t\t\tAnimationType.{v_animation_type}",
                "\t\t}",
            )
        )
    output.extend(("\t\telse { .none_ }", "\t}", "}", ""))

    animatable_properties = [
        v_property_name(name)
        for name, raw_property in properties.items()
        if isinstance(raw_property, dict)
        and not raw_property.get("legacy-alias-for")
        and property_is_animatable(properties, name)
    ]
    append_boolean_match(
        output,
        "pub fn is_animatable_property(property_id PropertyID) bool",
        animatable_properties,
    )

    output.extend(
        (
            "pub fn property_multiplicity(property_id PropertyID) PropertyMultiplicity {",
            "\treturn match property_id {",
        )
    )
    for multiplicity, properties_for_multiplicity in multiplicity_groups(properties).items():
        output.extend(
            (
                f"\t\t{match_cases(properties_for_multiplicity)} {{",
                f"\t\t\tPropertyMultiplicity.{multiplicity.replace('-', '_')}",
                "\t\t}",
            )
        )
    output.extend(("\t\telse { .single }", "\t}", "}", ""))

    for function_name, metadata_key, default in (
        ("property_affects_layout", "affects-layout", True),
        ("property_affects_stacking_context", "affects-stacking-context", False),
    ):
        matching_properties = boolean_metadata_properties(properties, metadata_key, default)
        append_boolean_match(
            output,
            f"pub fn {function_name}(property_id PropertyID) bool",
            matching_properties,
        )

    for function_name, accepted_requirements in (
        ("property_requires_computation_with_inherited_value", {"always"}),
        (
            "property_requires_computation_with_initial_value",
            {"always", "non-inherited-value"},
        ),
        (
            "property_requires_computation_with_cascaded_value",
            {"always", "non-inherited-value", "cascaded-value"},
        ),
    ):
        matching_properties = computation_requirement_properties(
            properties, accepted_requirements
        )
        append_boolean_match(
            output,
            f"pub fn {function_name}(property_id PropertyID) bool",
            matching_properties,
        )

    positional_shorthands = boolean_metadata_properties(
        properties, "positional-value-list-shorthand", False
    )
    append_boolean_match(
        output,
        "fn property_is_positional_value_list_shorthand(property_id PropertyID) bool",
        positional_shorthands,
    )

    output.extend(
        (
            "pub fn property_maximum_value_count(property_id PropertyID) usize {",
            "\treturn match property_id {",
        )
    )
    for maximum, properties_for_maximum in maximum_value_count_groups(properties).items():
        output.extend(
            (
                f"\t\t{match_cases(properties_for_maximum)} {{",
                f"\t\t\t{maximum}",
                "\t\t}",
            )
        )
    output.extend(("\t\telse { 1 }", "\t}", "}", ""))

    aliases_by_property: dict[str, list[tuple[str, str]]] = defaultdict(list)
    for property_name, from_keyword, to_keyword in legacy_value_aliases(properties):
        aliases_by_property[property_name].append((from_keyword, to_keyword))
    output.extend(
        (
            "pub fn resolve_legacy_value_alias(property_id PropertyID, keyword Keyword) ?Keyword {",
            "\treturn match property_id {",
        )
    )
    for property_name, aliases in aliases_by_property.items():
        output.extend((f"\t\t.{property_name} {{", "\t\t\tmatch keyword {"))
        for from_keyword, to_keyword in aliases:
            output.append(
                f"\t\t\t\t.{v_keyword_name(from_keyword)} {{ Keyword.{v_keyword_name(to_keyword)} }}"
            )
        output.extend(("\t\t\t\telse { none }", "\t\t\t}", "\t\t}"))
    output.extend(("\t\telse { none }", "\t}", "}", ""))

    output.extend(
        (
        "pub fn property_resolves_percentages_relative_to(property_id PropertyID) ?ValueType {",
        "\treturn match property_id {",
        )
    )
    for value_type, properties_for_type in percentage_groups(properties).items():
        output.extend(
            (
                f"\t\t{match_cases(properties_for_type)} {{",
                f"\t\t\tValueType.{value_type.replace('-', '_')}",
                "\t\t}",
            )
        )
    output.extend(("\t\telse { none }", "\t}", "}", ""))

    output.extend(
        (
            "pub fn property_accepts_type(property_id PropertyID, value_type ValueType) bool {",
            "\treturn match property_id {",
        )
    )
    for accepted_types, properties_for_types in accepted_type_groups(
        properties, enum_names
    ).items():
        accepted_expression = ", ".join(f".{value_type}" for value_type in accepted_types)
        if len(accepted_types) == 1:
            condition = f"value_type == {accepted_expression}"
        else:
            condition = f"value_type in [{accepted_expression}]"
        output.extend(
            (
                f"\t\t{match_cases(properties_for_types)} {{",
                f"\t\t\t{condition}",
                "\t\t}",
            )
        )
    output.extend(("\t\telse { false }", "\t}", "}", ""))

    output.extend(
        (
            "fn property_custom_ident_blacklist(property_id PropertyID) []string {",
            "\treturn match property_id {",
        )
    )
    for blacklist, properties_for_blacklist in custom_ident_blacklist_groups(
        properties
    ).items():
        serialized_blacklist = ", ".join(repr(keyword) for keyword in blacklist)
        output.extend(
            (
                f"\t\t{match_cases(properties_for_blacklist)} {{",
                f"\t\t\t[{serialized_blacklist}]",
                "\t\t}",
            )
        )
    output.extend(("\t\telse { [] }", "\t}", "}", ""))

    output.extend(
        (
            "fn property_accepts_keyword_string(property_id PropertyID, value string) bool {",
            "\tlowercase_value := to_ascii_lowercase(value)",
            "\treturn match property_id {",
        )
    )
    for keywords, properties_for_keywords in accepted_keyword_groups(
        properties, enums
    ).items():
        serialized_keywords = ", ".join(repr(keyword) for keyword in keywords)
        output.extend(
            (
                f"\t\t{match_cases(properties_for_keywords)} {{",
                f"\t\t\tlowercase_value in [{serialized_keywords}]",
                "\t\t}",
            )
        )
    output.extend(("\t\telse { false }", "\t}", "}", ""))

    output.extend(
        (
            "pub fn property_accepted_type_ranges(property_id PropertyID) map[ValueType]AcceptedTypeRange {",
            "\tmut ranges := map[ValueType]AcceptedTypeRange{}",
            "\tmatch property_id {",
        )
    )
    for ranges, properties_for_ranges in property_ranges(properties).items():
        output.append(f"\t\t{match_cases(properties_for_ranges)} {{")
        for value_type, minimum, maximum in ranges:
            output.extend(
                (
                    f"\t\t\tranges[.{value_type.replace('-', '_')}] = AcceptedTypeRange{{",
                    f"\t\t\t\tmin: {minimum}",
                    f"\t\t\t\tmax: {maximum}",
                    "\t\t\t}",
                )
            )
        output.append("\t\t}")
    output.extend(("\t\telse {}", "\t}", "\treturn ranges", "}", ""))

    for value_type, (v_type, getter) in BOUND_CHECK_TYPES.items():
        groups = bound_check_groups(properties, value_type)
        if not groups:
            output.extend(
                (
                    f"pub fn property_accepts_{value_type}(property_id PropertyID, value {v_type}) bool {{",
                    "\t_ = property_id",
                    "\t_ = value",
                    "\treturn false",
                    "}",
                    "",
                )
            )
            continue
        output.extend(
            (
                f"pub fn property_accepts_{value_type}(property_id PropertyID, value {v_type}) bool {{",
                "\treturn match property_id {",
            )
        )
        for (minimum, maximum), properties_for_range in groups.items():
            output.extend(
                (
                    f"\t\t{match_cases(properties_for_range)} {{",
                    f"\t\t\t{bound_check_expression(getter, minimum, maximum)}",
                    "\t\t}",
                )
            )
        output.extend(("\t\telse { false }", "\t}", "}", ""))
    return "\n".join(output)


def main() -> int:
    args = parse_args()
    properties_path = args.ladybird / "Libraries/LibWeb/CSS/Properties.json"
    logical_property_groups_path = (
        args.ladybird / "Libraries/LibWeb/CSS/LogicalPropertyGroups.json"
    )
    enums_path = args.ladybird / "Libraries/LibWeb/CSS/Enums.json"
    properties = json.loads(properties_path.read_text())
    logical_property_groups = json.loads(logical_property_groups_path.read_text())
    properties = replace_logical_aliases(properties, logical_property_groups)
    properties = populate_all_property_longhands(properties)
    enums = json.loads(enums_path.read_text())
    target = args.translation / "css/property_calculation_metadata.v"
    target.write_text(generate(properties, enums))
    print(f"translated calculation metadata for {len(properties)} CSS properties from {properties_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
