#!/usr/bin/env python3
"""Audit function-level LibWeb changes between two Ladybird revisions.

Line churn is useful for sizing the source review, but it cannot distinguish a
function moved between files from newly introduced behavior.  This tool parses
out-of-line and header-inline function bodies at both revisions, matches exact
bodies across moves within a module, and reports the remaining added, changed,
and removed definitions.  Current definitions are also joined to the V symbol
audit so the report can be used as a translation review queue.
"""

from __future__ import annotations

import argparse
import collections
import json
import re
import subprocess
import tarfile
import tempfile
from dataclasses import asdict, dataclass
from pathlib import Path

import html_translation_audit as html_audit
import libweb_translation_audit as libweb_audit


DEFAULT_UPSTREAM = Path.home() / "code/3rd/ladybird"
DEFAULT_BASE = "1d025620e3344e3cc9aee26fe815d8675e4f9810"


@dataclass(frozen=True)
class Definition:
    source: str
    line: int
    owner: str
    name: str
    signature: str
    body: str

    @property
    def module(self) -> str:
        relative = self.source.removeprefix("Libraries/LibWeb/")
        return relative.split("/", 1)[0] if "/" in relative else "(root support)"

    @property
    def module_source(self) -> str:
        relative = self.source.removeprefix("Libraries/LibWeb/")
        return relative.split("/", 1)[1] if "/" in relative else relative


@dataclass(frozen=True)
class DeltaEntry:
    kind: str
    module: str
    source: str
    line: int
    owner: str
    name: str
    old_source: str | None = None
    old_line: int | None = None
    disposition: str | None = None
    candidate_v_functions: tuple[str, ...] = ()


def git(upstream: Path, *arguments: str, binary: bool = False) -> str | bytes:
    return subprocess.check_output(
        ["git", "-C", str(upstream), *arguments],
        text=not binary,
    )


def normalize_cpp(text: str) -> str:
    """Remove comments and insignificant whitespace while preserving literals."""
    output: list[str] = []
    index = 0
    pending_space = False
    while index < len(text):
        if text.startswith("//", index):
            newline = text.find("\n", index + 2)
            index = len(text) if newline < 0 else newline + 1
            pending_space = True
            continue
        if text.startswith("/*", index):
            end = text.find("*/", index + 2)
            index = len(text) if end < 0 else end + 2
            pending_space = True
            continue
        raw = re.match(r'R"(?P<tag>[^ (\\\t\r\n]{0,16})\(', text[index:])
        if raw:
            terminator = ")" + raw.group("tag") + '"'
            end = text.find(terminator, index + raw.end())
            end = len(text) if end < 0 else end + len(terminator)
            if pending_space and output:
                output.append(" ")
            output.append(text[index:end])
            pending_space = False
            index = end
            continue
        character = text[index]
        if character in {'"', "'"}:
            start = index
            quote = character
            index += 1
            while index < len(text):
                if text[index] == "\\":
                    index += 2
                    continue
                index += 1
                if text[index - 1] == quote:
                    break
            if pending_space and output:
                output.append(" ")
            output.append(text[start:index])
            pending_space = False
            continue
        if character.isspace():
            pending_space = True
            index += 1
            continue
        if pending_space and output:
            output.append(" ")
        output.append(character)
        pending_space = False
        index += 1
    return "".join(output).strip()


def function_body_opening(text: str, parameters_opening: int) -> int | None:
    parameters_closing = html_audit.matching_closing_parenthesis(text, parameters_opening)
    if parameters_closing is None:
        return None
    parenthesis_depth = 0
    square_depth = 0
    for index in range(parameters_closing + 1, min(len(text), parameters_closing + 4000)):
        character = text[index]
        if character == "(":
            parenthesis_depth += 1
        elif character == ")" and parenthesis_depth:
            parenthesis_depth -= 1
        elif character == "[":
            square_depth += 1
        elif character == "]" and square_depth:
            square_depth -= 1
        elif parenthesis_depth == 0 and square_depth == 0:
            if character == "{":
                return index
            if character in ";#":
                return None
    return None


def definition_from_match(
    raw: str,
    sanitized: str,
    source: str,
    match: re.Match[str],
    owner: str,
    name: str,
) -> Definition | None:
    parameters_opening = match.end() - 1
    body_opening = function_body_opening(sanitized, parameters_opening)
    if body_opening is None:
        return None
    body_closing = html_audit.matching_closing_brace(sanitized, body_opening)
    if body_closing is None:
        return None
    return Definition(
        source=source,
        line=raw.count("\n", 0, match.start()) + 1,
        owner=owner,
        name=name,
        signature=normalize_cpp(raw[match.start() : body_opening]),
        body=normalize_cpp(raw[body_opening : body_closing + 1]),
    )


def cpp_definitions(source: str, raw: str) -> list[Definition]:
    sanitized = html_audit.strip_cpp_comments(raw)
    definitions: list[Definition] = []
    occupied: list[tuple[int, int]] = []
    for match in html_audit.CPP_METHOD.finditer(sanitized):
        owner = match.group("class").split("::")[-1]
        name = match.group("name")
        definition = definition_from_match(raw, sanitized, source, match, owner, name)
        if definition is None:
            continue
        definitions.append(definition)
        occupied.append((match.start(), match.end()))

    for match in html_audit.CPP_FREE_FUNCTION_HEAD.finditer(sanitized):
        name_start = match.start("name")
        if sanitized[max(0, name_start - 2) : name_start] == "::":
            continue
        if any(start <= match.start() < end for start, end in occupied):
            continue
        name = re.sub(r"\s+", "", match.group("name"))
        if name in {"alignof", "decltype", "noexcept", "requires", "sizeof"}:
            continue
        if re.fullmatch(r"[A-Z][A-Z0-9_]*", name):
            continue
        definition = definition_from_match(
            raw, sanitized, source, match, "<namespace>", name
        )
        if definition is not None:
            definitions.append(definition)
    return sorted(definitions, key=lambda item: (item.source, item.line, item.owner, item.name))


def header_definitions(source: str, raw: str) -> list[Definition]:
    sanitized = html_audit.strip_cpp_comments(raw)
    definitions: list[Definition] = []
    for class_match in html_audit.HEADER_CLASS.finditer(sanitized):
        owner = class_match.group("name").split("::")[-1]
        class_opening = class_match.end() - 1
        class_closing = html_audit.matching_closing_brace(sanitized, class_opening)
        if class_closing is None:
            continue
        index = class_opening + 1
        segment_start = index
        while index < class_closing:
            if sanitized[index] != "{":
                index += 1
                continue
            candidate = sanitized[segment_start : index + 1]
            matches = list(html_audit.HEADER_INLINE_METHOD.finditer(candidate))
            body_closing = html_audit.matching_closing_brace(sanitized, index)
            if body_closing is None:
                break
            if matches:
                match = matches[-1]
                absolute_start = segment_start + match.start()
                absolute_parameters = segment_start + match.end() - 1
                name = match.group("name")
                if not re.fullmatch(r"[A-Z][A-Z0-9_]*", name):
                    definitions.append(
                        Definition(
                            source=source,
                            line=raw.count("\n", 0, absolute_start) + 1,
                            owner=owner,
                            name=name,
                            signature=normalize_cpp(raw[absolute_start:index]),
                            body=normalize_cpp(raw[index : body_closing + 1]),
                        )
                    )
            index = body_closing + 1
            segment_start = index
    return sorted(definitions, key=lambda item: (item.source, item.line, item.owner, item.name))


def definitions_below(libweb: Path) -> list[Definition]:
    definitions: list[Definition] = []
    for source in sorted(libweb.rglob("*.cpp")):
        relative = source.relative_to(libweb.parents[1]).as_posix()
        definitions.extend(cpp_definitions(relative, source.read_text(errors="replace")))
    for source in sorted(libweb.rglob("*.h")):
        relative = source.relative_to(libweb.parents[1]).as_posix()
        definitions.extend(header_definitions(relative, source.read_text(errors="replace")))
    return definitions


def extract_revision(upstream: Path, revision: str, destination: Path) -> Path:
    destination.mkdir(parents=True, exist_ok=True)
    archive = git(
        upstream,
        "archive",
        "--format=tar",
        revision,
        "Libraries/LibWeb",
        binary=True,
    )
    archive_path = destination / "libweb.tar"
    archive_path.write_bytes(archive)
    with tarfile.open(archive_path) as tar:
        destination_root = destination.resolve()
        for member in tar.getmembers():
            member_path = (destination / member.name).resolve()
            if destination_root not in member_path.parents and member_path != destination_root:
                raise ValueError(f"archive member escapes destination: {member.name}")
        tar.extractall(destination)
    archive_path.unlink()
    return destination / "Libraries/LibWeb"


def pop_exact_matches(
    old: list[Definition], current: list[Definition]
) -> tuple[list[Definition], list[Definition]]:
    old_by_body: dict[tuple[str, str, str, str], list[Definition]] = collections.defaultdict(list)
    for definition in old:
        old_by_body[(definition.module, definition.owner, definition.name, definition.body)].append(definition)
    unmatched_current: list[Definition] = []
    for definition in current:
        key = (definition.module, definition.owner, definition.name, definition.body)
        if old_by_body[key]:
            old_by_body[key].pop()
        else:
            unmatched_current.append(definition)
    unmatched_old = [definition for bucket in old_by_body.values() for definition in bucket]
    return unmatched_old, unmatched_current


def compare_definitions(old: list[Definition], current: list[Definition]) -> list[DeltaEntry]:
    remaining_old, remaining_current = pop_exact_matches(old, current)
    old_groups: dict[tuple[str, str, str], list[Definition]] = collections.defaultdict(list)
    current_groups: dict[tuple[str, str, str], list[Definition]] = collections.defaultdict(list)
    for definition in remaining_old:
        old_groups[(definition.module, definition.owner, definition.name)].append(definition)
    for definition in remaining_current:
        current_groups[(definition.module, definition.owner, definition.name)].append(definition)

    entries: list[DeltaEntry] = []
    for key in sorted(set(old_groups) | set(current_groups)):
        old_group = sorted(old_groups[key], key=lambda item: (item.source, item.line, item.signature))
        current_group = sorted(current_groups[key], key=lambda item: (item.source, item.line, item.signature))
        paired = min(len(old_group), len(current_group))
        for index in range(paired):
            before = old_group[index]
            after = current_group[index]
            entries.append(
                DeltaEntry(
                    kind="changed",
                    module=after.module,
                    source=after.module_source,
                    line=after.line,
                    owner=after.owner,
                    name=after.name,
                    old_source=before.module_source,
                    old_line=before.line,
                )
            )
        for after in current_group[paired:]:
            entries.append(
                DeltaEntry(
                    kind="added",
                    module=after.module,
                    source=after.module_source,
                    line=after.line,
                    owner=after.owner,
                    name=after.name,
                )
            )
        for before in old_group[paired:]:
            entries.append(
                DeltaEntry(
                    kind="removed",
                    module=before.module,
                    source=before.module_source,
                    line=before.line,
                    owner=before.owner,
                    name=before.name,
                    old_source=before.module_source,
                    old_line=before.line,
                )
            )
    return sorted(entries, key=lambda item: (item.module, item.source, item.line, item.kind))


def join_v_dispositions(
    entries: list[DeltaEntry], ladybird: Path, translation: Path
) -> list[DeltaEntry]:
    functions, _, _ = libweb_audit.all_v_function_names(translation)
    fields = libweb_audit.all_v_field_names(translation)
    current_inventory: dict[tuple[str, str, str], list[html_audit.UpstreamMethod]] = collections.defaultdict(list)
    libweb = ladybird / "Libraries/LibWeb"
    for module in sorted(path for path in libweb.iterdir() if path.is_dir()):
        if not list(module.rglob("*.cpp")):
            continue
        for method in libweb_audit.module_inventory(module, functions, fields):
            current_inventory[(module.name, method.class_name, method.name)].append(method)

    joined: list[DeltaEntry] = []
    for entry in entries:
        if entry.kind == "removed":
            joined.append(entry)
            continue
        candidates = current_inventory[(entry.module, entry.owner, entry.name)]
        exact_source = [candidate for candidate in candidates if candidate.source == entry.source]
        match = min(exact_source or candidates, key=lambda item: abs(item.line - entry.line), default=None)
        if match is None:
            joined.append(entry)
        else:
            joined.append(
                DeltaEntry(
                    **{
                        **asdict(entry),
                        "disposition": match.disposition,
                        "candidate_v_functions": match.candidate_v_functions,
                    }
                )
            )
    return joined


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--upstream", type=Path, default=DEFAULT_UPSTREAM)
    parser.add_argument("--translation", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--base", default=DEFAULT_BASE)
    parser.add_argument("--head", default="HEAD")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    base = str(git(args.upstream, "rev-parse", args.base)).strip()
    head = str(git(args.upstream, "rev-parse", args.head)).strip()
    with tempfile.TemporaryDirectory(prefix="libweb-function-delta-") as temporary:
        temporary_root = Path(temporary)
        old_root = extract_revision(args.upstream, base, temporary_root / "base")
        current_root = extract_revision(args.upstream, head, temporary_root / "head")
        entries = compare_definitions(definitions_below(old_root), definitions_below(current_root))
    entries = join_v_dispositions(entries, args.upstream, args.translation)

    counts = collections.Counter(entry.kind for entry in entries)
    by_module: dict[str, collections.Counter[str]] = collections.defaultdict(collections.Counter)
    dispositions: collections.Counter[str] = collections.Counter()
    for entry in entries:
        by_module[entry.module][entry.kind] += 1
        if entry.kind != "removed":
            dispositions[entry.disposition or "not-in-current-audit"] += 1
    payload = {
        "base": base,
        "head": head,
        "counts": dict(sorted(counts.items())),
        "dispositions": dict(sorted(dispositions.items())),
        "modules": {module: dict(sorted(count.items())) for module, count in sorted(by_module.items())},
        "entries": [asdict(entry) for entry in entries],
    }
    if args.json:
        print(json.dumps(payload, indent=2))
    else:
        print(f"base: {base}")
        print(f"head: {head}")
        print(
            "definitions: "
            f"{counts['added']:,} added, {counts['changed']:,} changed, "
            f"{counts['removed']:,} removed"
        )
        print("current added/changed V dispositions:")
        for disposition, count in dispositions.most_common():
            print(f"  {disposition}: {count:,}")
        print("module definition delta:")
        for module, count in sorted(by_module.items(), key=lambda item: (-sum(item[1].values()), item[0])):
            print(
                f"  {module:28} +{count['added']:5,d}"
                f"  ~{count['changed']:5,d}  -{count['removed']:5,d}"
            )
    return 1 if dispositions["unmatched"] or dispositions["not-in-current-audit"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
