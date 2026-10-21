#!/usr/bin/env python3
"""Translate Ladybird's generated CSS Keyword table to V.

The C++ table is generated from all CSS grammars.  Keeping a hand-selected V
subset made otherwise valid values fall through to string-backed stubs.  This
generator preserves existing V enum spellings and adds every upstream keyword.
"""

from __future__ import annotations

import argparse
import collections
import re
from pathlib import Path


PAIR = re.compile(r'^\s*\{"([^"]+)"sv, Keyword::([A-Za-z0-9_]+)\},\s*$', re.MULTILINE)
V_ARM = re.compile(r"^\s*\.([A-Za-z0-9_]+)\s*\{\s*'([^']*)'\s*\}\s*$", re.MULTILINE)
V_RESERVED = {
    "as", "asm", "assert", "atomic", "break", "chan", "const", "continue",
    "defer", "else", "enum", "false", "fn", "for", "go", "goto", "if",
    "import", "in", "interface", "is", "lock", "map", "match", "module",
    "mut", "none", "or", "pub", "return", "rlock", "select", "shared",
    "sizeof", "spawn", "static", "struct", "true", "type", "typeof", "union",
    "unsafe",
}


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


def generated_keyword_cpp(ladybird: Path) -> Path:
    release = ladybird / "Build/release/Lagom/Libraries/LibWeb/CSS/Keyword.cpp"
    if release.is_file():
        return release
    candidates = sorted(ladybird.glob("Build/*/Lagom/Libraries/LibWeb/CSS/Keyword.cpp"))
    if not candidates:
        raise SystemExit("build Ladybird first: generated CSS/Keyword.cpp was not found")
    return candidates[0]


def fallback_case(css_text: str) -> str:
    if css_text == "-infinity":
        return "negative_infinity"
    case = re.sub(r"[^a-z0-9]+", "_", css_text.lower()).strip("_")
    if not case or case[0].isdigit():
        case = f"keyword_{case}"
    if case in V_RESERVED:
        case += "_"
    return case


def replace_block(source: str, start_pattern: str, end_pattern: str, replacement: str) -> str:
    start = re.search(start_pattern, source, re.MULTILINE)
    if not start:
        raise SystemExit(f"start marker not found: {start_pattern}")
    end = re.search(end_pattern, source[start.end():], re.MULTILINE)
    if not end:
        raise SystemExit(f"end marker not found: {end_pattern}")
    end_offset = start.end() + end.start()
    return source[:start.start()] + replacement + source[end_offset:]



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

def main() -> int:
    args = parse_args()
    target = args.translation / "css/style_values_core.v"
    source = target.read_text()
    upstream = generated_keyword_cpp(args.ladybird).read_text()
    keywords = [css_text for css_text, _ in PAIR.findall(upstream)]
    if len(keywords) < 800 or len(set(keywords)) != len(keywords):
        raise SystemExit(f"unexpected upstream keyword table: {len(keywords)} entries")

    existing_cases = {css_text: case for case, css_text in V_ARM.findall(source)}
    used_cases: dict[str, str] = {"invalid": ""}
    rows: list[tuple[str, str]] = []
    for css_text in keywords:
        case = existing_cases.get(css_text, fallback_case(css_text))
        if previous := used_cases.get(case):
            raise SystemExit(f"V enum collision: {previous!r} and {css_text!r} -> {case}")
        used_cases[case] = css_text
        rows.append((css_text, case))

    enum = "pub enum Keyword {\n\tinvalid\n" + "".join(f"\t{case}\n" for _, case in rows) + "}\n\n"
    source = replace_block(source, r"^pub enum Keyword \{\n", r"^pub fn \(keyword Keyword\) is_css_wide_keyword\(", enum)

    to_string = "pub fn string_from_keyword(keyword Keyword) string {\n\treturn match keyword {\n"
    to_string += "\t\t.invalid { '' }\n"
    to_string += "".join(f"\t\t.{case} {{ '{css_text}' }}\n" for css_text, case in rows)
    to_string += "\t}\n}\n\n"
    source = replace_block(source, r"^pub fn string_from_keyword\(keyword Keyword\) string \{\n", r"^pub fn keyword_from_string\(", to_string)

    from_string = "pub fn keyword_from_string(input string) ?Keyword {\n\tname := to_ascii_lowercase(input)\n"
    from_string += dispatched_lookup(rows, 'name', 'Keyword') + "}\n\n"
    source = replace_block(source, r"^pub fn keyword_from_string\(input string\) \?Keyword \{\n", r"^// --- StyleValue ---", from_string)

    target.write_text(source)
    print(f"translated {len(rows)} CSS keywords from {generated_keyword_cpp(args.ladybird)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
