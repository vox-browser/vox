#!/usr/bin/env python3
"""Compile Vox's C++ ABI bridges with the Linux dependency flags."""

import hashlib
import os
from pathlib import Path
import shlex
import subprocess


def main():
    repo = Path(__file__).resolve().parent.parent
    output = repo / "Build/linux/native"
    output.mkdir(parents=True, exist_ok=True)
    compiler = shlex.split(os.environ.get("CXX", "c++"))
    version = subprocess.check_output(compiler + ["--version"])
    for package, names, dependencies in [
        ("platform", ["unicode_case_mapping"], ["icu-uc", "icu-i18n"]),
        ("gfxfont", ["woff2"], []),
        ("skia", ["canvas_raster", "shadow_raster"], ["skia"]),
    ]:
        flags = shlex.split(subprocess.check_output(
            ["pkg-config", "--cflags", *dependencies], text=True)) if dependencies else []
        digest = hashlib.sha256(version + repr(flags).encode() + Path(__file__).read_bytes())
        sources = [repo / package / (name + ".cpp") for name in names]
        for path in [*sources, *sorted((repo / package).glob("*.h"))]:
            digest.update(path.read_bytes())
        archive = output / (package + ".a")
        stamp = archive.with_suffix(".sha256")
        if archive.is_file() and stamp.is_file() and stamp.read_text() == digest.hexdigest():
            continue
        objects = []
        for source in sources:
            target = output / (source.stem + ".o")
            subprocess.run(compiler + ["-std=c++20", "-O2", "-fPIC", *flags,
                                      "-c", str(source), "-o", str(target)], check=True)
            objects.append(str(target))
        temporary = archive.with_suffix(".tmp.a")
        temporary.unlink(missing_ok=True)
        subprocess.run(["ar", "rcs", str(temporary), *objects], check=True)
        temporary.replace(archive)
        stamp.write_text(digest.hexdigest())
        print(f"Built Linux {package} bridge")


if __name__ == "__main__":
    main()
