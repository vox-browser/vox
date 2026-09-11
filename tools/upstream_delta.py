#!/usr/bin/env python3
"""Measure the LibWeb C++ delta since the V translation's 2026-03-24 base.

The primary number is added `.cpp` lines in module-owned implementation units:
those are the new implementation lines that need review/translation. Deletions
are reported separately and as churn because rewrites also require revisiting
already translated behavior.
"""

from __future__ import annotations

import argparse
import collections
import subprocess
from dataclasses import dataclass
from pathlib import Path


DEFAULT_UPSTREAM = Path.home() / "code/3rd/ladybird"
DEFAULT_BASE = "1d025620e3344e3cc9aee26fe815d8675e4f9810"


@dataclass
class Delta:
    files: int = 0
    additions: int = 0
    deletions: int = 0

    @property
    def churn(self) -> int:
        return self.additions + self.deletions

    def add(self, additions: int, deletions: int) -> None:
        self.files += 1
        self.additions += additions
        self.deletions += deletions


def git(upstream: Path, *arguments: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(upstream), *arguments], text=True
    ).strip()


def parse_numstat(output: str) -> list[tuple[int, int, str]]:
    rows: list[tuple[int, int, str]] = []
    for line in output.splitlines():
        additions, deletions, path = line.split("\t", 2)
        rows.append(
            (
                0 if additions == "-" else int(additions),
                0 if deletions == "-" else int(deletions),
                path,
            )
        )
    return rows


def module_for(path: str) -> str | None:
    prefix = "Libraries/LibWeb/"
    if not path.startswith(prefix):
        return None
    relative = path[len(prefix) :]
    if "/" not in relative:
        return "(root support)"
    return relative.split("/", 1)[0]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--upstream", type=Path, default=DEFAULT_UPSTREAM)
    parser.add_argument("--base", default=DEFAULT_BASE)
    parser.add_argument("--head", default="HEAD")
    parser.add_argument("--all", action="store_true", help="show modules with zero .cpp churn")
    args = parser.parse_args()

    base = git(args.upstream, "rev-parse", args.base)
    head = git(args.upstream, "rev-parse", args.head)
    base_description = git(args.upstream, "show", "-s", "--format=%cI %s", base)
    head_description = git(args.upstream, "show", "-s", "--format=%cI %s", head)
    rows = parse_numstat(
        git(
            args.upstream,
            "diff",
            "--numstat",
            "--no-renames",
            f"{base}..{head}",
            "--",
            "Libraries/LibWeb",
        )
    )

    cpp_by_module: dict[str, Delta] = collections.defaultdict(Delta)
    headers = Delta()
    for additions, deletions, path in rows:
        module = module_for(path)
        if module is None:
            continue
        if path.endswith(".cpp"):
            cpp_by_module[module].add(additions, deletions)
        elif path.endswith(".h"):
            headers.add(additions, deletions)

    module_cpp = Delta()
    root_cpp = cpp_by_module.get("(root support)", Delta())
    for module, delta in cpp_by_module.items():
        if module != "(root support)":
            module_cpp.files += delta.files
            module_cpp.additions += delta.additions
            module_cpp.deletions += delta.deletions

    all_cpp_and_headers = Delta(
        files=module_cpp.files + root_cpp.files + headers.files,
        additions=module_cpp.additions + root_cpp.additions + headers.additions,
        deletions=module_cpp.deletions + root_cpp.deletions + headers.deletions,
    )

    commits = int(git(args.upstream, "rev-list", "--count", f"{base}..{head}"))
    libweb_commits = int(
        git(
            args.upstream,
            "rev-list",
            "--count",
            f"{base}..{head}",
            "--",
            "Libraries/LibWeb",
        )
    )
    print(f"base: {base}  {base_description}")
    print(f"head: {head}  {head_description}")
    print(f"commits: {commits:,} total; {libweb_commits:,} touching Libraries/LibWeb")
    print()
    print("scope                              files    additions    deletions       churn")
    print(
        f"module-owned .cpp              {module_cpp.files:7,d}"
        f" {module_cpp.additions:12,d} {module_cpp.deletions:12,d} {module_cpp.churn:11,d}"
    )
    print(
        f"root-support .cpp              {root_cpp.files:7,d}"
        f" {root_cpp.additions:12,d} {root_cpp.deletions:12,d} {root_cpp.churn:11,d}"
    )
    print(
        f"all LibWeb headers             {headers.files:7,d}"
        f" {headers.additions:12,d} {headers.deletions:12,d} {headers.churn:11,d}"
    )
    print(
        f"all .cpp and headers           {all_cpp_and_headers.files:7,d}"
        f" {all_cpp_and_headers.additions:12,d}"
        f" {all_cpp_and_headers.deletions:12,d} {all_cpp_and_headers.churn:11,d}"
    )
    print()
    print("module .cpp churn:")
    for module, delta in sorted(
        cpp_by_module.items(), key=lambda item: (-item[1].churn, item[0])
    ):
        if module == "(root support)" or (not args.all and delta.churn == 0):
            continue
        print(
            f"  {module:28} {delta.files:5,d} files"
            f"  +{delta.additions:8,d}  -{delta.deletions:8,d}  churn {delta.churn:9,d}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
