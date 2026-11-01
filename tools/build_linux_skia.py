#!/usr/bin/env python3
"""Build the pinned CPU Skia dependency used by Vox on Linux (GN + Ninja)."""

import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import urllib.request

REVISION = "ee20d565acb08dece4a32e3f209cdd41119015ca"
SHA512 = ("afa54cb14b76e9b2f40498c5daf93cec951d12d7f3487deba6f8f94a66d046a5625561"
          "e1ccd65f2e9ef5e2fc1a3158c3da4fb9658bcf268248a34c49dea90d3a")


def main():
    if os.uname().sysname != "Linux":
        raise SystemExit("This dependency build must run on Linux")
    for tool in ("gn", "ninja", "clang", "clang++", "pkg-config"):
        if not shutil.which(tool):
            raise SystemExit(f"Missing {tool}; see docs/LINUX.md")
    root = Path(__file__).resolve().parent.parent / "Build/deps"
    root.mkdir(parents=True, exist_ok=True)
    archive = root / "skia.tar.gz"
    if not archive.is_file():
        temporary = archive.with_suffix(".tmp")
        urllib.request.urlretrieve(
            f"https://codeload.github.com/google/skia/tar.gz/{REVISION}", temporary)
        temporary.replace(archive)
    if hashlib.sha512(archive.read_bytes()).hexdigest() != SHA512:
        raise SystemExit(f"Skia archive checksum mismatch: {archive}")
    source = root / "skia"
    stamp = source / ".vox-revision"
    if not source.exists():
        with tarfile.open(archive) as bundle:
            bundle.extractall(root, filter="data")
        (root / f"skia-{REVISION}").rename(source)
        stamp.write_text(REVISION + "\n")
    elif not stamp.is_file() or stamp.read_text().strip() != REVISION:
        raise SystemExit(f"Unrecognized Skia source tree: {source}")
    # Match upstream Ladybird's always-build-pathops patch. CPU-only Skia
    # otherwise omits Op(), which the shadow rasterizer uses for inner clips.
    build_file = source / "BUILD.gn"
    text = build_file.read_text()
    component = text.index('skia_component("skia") {')
    prefix, text = text[:component], text[component:]
    original = '    ":jpeg_encode",\n    ":pdf",'
    replacement = '    ":jpeg_encode",\n    ":pathops",\n    ":pdf",'
    if original in text:
        if text.count(original) != 1:
            raise SystemExit("Unrecognized Skia pathops dependency list")
        build_file.write_text(prefix + text.replace(original, replacement, 1))
    elif replacement not in text:
        raise SystemExit("Missing Skia pathops dependency list")
    args = " ".join([
        'is_official_build=true is_debug=false cc="clang" cxx="clang++"',
        "skia_enable_ganesh=false skia_enable_graphite=false skia_enable_pdf=false",
        "skia_enable_tools=false skia_use_icu=false skia_use_harfbuzz=false",
        "skia_use_freetype=true skia_use_fontconfig=true skia_use_wuffs=false",
        "skia_use_piex=false skia_use_dng_sdk=false skia_use_expat=false",
        'skia_use_libavif=false skia_use_lua=false extra_cflags=["-fPIC"]',
    ])
    subprocess.run(["gn", "gen", "out/Release", f"--args={args}"], cwd=source, check=True)
    subprocess.run(["ninja", "-C", "out/Release", "-j", os.environ.get("JOBS", "3"), "skia"],
                   cwd=source, check=True)
    pkgconfig = root / "lib/pkgconfig"
    pkgconfig.mkdir(parents=True, exist_ok=True)
    (pkgconfig / "skia.pc").write_text(
        f"prefix={source}\nName: skia\nDescription: Vox CPU Skia\nVersion: 144\n"
        "Libs: -L${prefix}/out/Release -lskia -lskcms -lstdc++ -ldl -lpthread -lm\n"
        "Requires: freetype2 fontconfig libpng libjpeg libwebp libwebpdemux zlib\n"
        "Cflags: -I${prefix} -DSK_HIDE_PATH_EDIT_METHODS -DSK_R32_SHIFT=16\n")
    print(f"Built Skia {REVISION}; run sh build-prod-browser.sh")


if __name__ == "__main__":
    main()
