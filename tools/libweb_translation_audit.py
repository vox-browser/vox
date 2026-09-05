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


def suspicious_trivial_implementation_inventory(translation: Path) -> list[dict[str, object]]:
    """Find silent empty/default-return bodies that name coverage misses.

    This is intentionally an investigation queue, not an automatic assertion
    of divergence: a handful of upstream methods are legitimately constant or
    no-op. Each result must still be compared with the corresponding C++ body.
    """
    findings: list[dict[str, object]] = []
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
            findings.append(
                {
                    "source": source.relative_to(translation).as_posix(),
                    "line": line,
                    "owner": owner,
                    "name": function.group("name"),
                    "body": "\n".join(statements),
                }
            )
    return findings


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
    suspicious_trivial_implementations = suspicious_trivial_implementation_inventory(args.translation)
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
