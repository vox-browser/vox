#!/usr/bin/env python3
"""Compile Vox's C++ ABI bridges with Linux or Windows dependency flags."""

import hashlib
import argparse
import os
from pathlib import Path
import shlex
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--os', choices=['linux', 'windows'], default='linux')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    output = repo / ('Build/deps/windows/native' if args.os == 'windows' else 'Build/linux/native')
    output.mkdir(parents=True, exist_ok=True)
    compiler = shlex.split(os.environ.get("CXX", "c++"))
    version = subprocess.check_output(compiler + ["--version"])
    groups = []
    if args.os == 'windows':
        groups.append(('webgl', ['native_windows'], ['vox-mesa-egl', 'icu-uc']))
    for package, names, dependencies in groups:
        flags = shlex.split(subprocess.check_output(
            ["pkg-config", "--cflags", *dependencies], text=True)) if dependencies else []
        digest = hashlib.sha256(version + repr(flags).encode() + Path(__file__).read_bytes())
        sources = [repo / package / (name + ('.c' if package == 'webgl' else '.cpp')) for name in names]
        for path in [*sources, *sorted((repo / package).glob("*.h"))]:
            digest.update(path.read_bytes())
        archive = output / (package + ".a")
        stamp = archive.with_suffix(".sha256")
        if archive.is_file() and stamp.is_file() and stamp.read_text() == digest.hexdigest():
            continue
        objects = []
        for source in sources:
            target = output / (source.stem + ".o")
            selected_compiler = shlex.split(os.environ.get('CC', 'cc')) if source.suffix == '.c' else compiler
            standard = '-std=gnu11' if source.suffix == '.c' else '-std=c++20'
            subprocess.run(selected_compiler + [standard, "-O2", "-fPIC", *flags,
                                      "-c", str(source), "-o", str(target)], check=True)
            objects.append(str(target))
        temporary = archive.with_suffix(".tmp.a")
        temporary.unlink(missing_ok=True)
        subprocess.run(shlex.split(os.environ.get('AR', 'ar')) + ["rcs", str(temporary), *objects], check=True)
        temporary.replace(archive)
        stamp.write_text(digest.hexdigest())
        print(f"Built {args.os} {package} bridge")


if __name__ == "__main__":
    main()
