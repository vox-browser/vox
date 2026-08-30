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
import json
from dataclasses import asdict
from pathlib import Path

import html_translation_audit as html_audit


EXCLUDED_TRANSLATION_DIRECTORIES = {
    ".git",
    "Build",
    "third_party",
}


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


def all_v_function_names(translation: Path) -> set[tuple[str, str | None]]:
    functions: set[tuple[str, str | None]] = set()
    for source in translation.rglob("*.v"):
        if source.name.endswith("_test.v"):
            continue
        if any(part in EXCLUDED_TRANSLATION_DIRECTORIES for part in source.parts):
            continue
        text = source.read_text(errors="replace")
        for match in html_audit.V_FUNCTION.finditer(text):
            owner = match.group("associated")
            if receiver := match.group("receiver"):
                receiver_type = receiver.split()[-1].lstrip("&?")
                owner = receiver_type.split(".")[-1]
            functions.add((match.group("name"), owner))
        for interface in html_audit.V_INTERFACE.finditer(text):
            owner = interface.group("name")
            for method in html_audit.V_INTERFACE_METHOD.finditer(interface.group("body")):
                functions.add((method.group("name"), owner))
    return functions


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

    functions = all_v_function_names(args.translation)
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
