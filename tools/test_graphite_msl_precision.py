#!/usr/bin/env python3
"""Check exact MSL rewriting and authenticated Skia patch installation."""
import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import tarfile

from build_mac_graphite import (LEGACY_MSL_SHA256, PATCH_INPUTS, REVISION,
                                prepare_precision_patch)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    repo = Path(__file__).resolve().parent.parent
    archive = repo / "Build/deps/skia-brave" / f"{REVISION}.tar.gz"
    patch = repo / "tools/skia_chromium_metal.patch"
    source = output / "source"
    with tarfile.open(archive) as bundle:
        for name in PATCH_INPUTS:
            target = source / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(bundle.extractfile(f"skia-{REVISION}/{name}").read())
    original = {name: (source / name).read_bytes() for name in PATCH_INPUTS}
    prepare_precision_patch(source, archive, patch)
    patched = {name: (source / name).read_bytes() for name in PATCH_INPUTS}
    prepare_precision_patch(source, archive, patch)
    assert patched == {name: (source / name).read_bytes() for name in PATCH_INPUTS}
    msl_name = "src/gpu/graphite/mtl/MtlGraphiteUtils.mm"
    text = patched[msl_name].decode()
    helper = text.split("// VOX_MSL_PRECISION_BEGIN\n", 1)[1].split("// VOX_MSL_PRECISION_END", 1)[0]
    (output / "vox_msl_precision_under_test.h").write_text(
        "#include <string>\n#include <string_view>\n" + helper)
    # Reconstruct the exact previous patch, then exercise the in-place upgrade.
    legacy = text.replace("#include <string>\n#include <string_view>", "#include <regex>")
    begin = legacy.index("// VOX_MSL_PRECISION_BEGIN")
    end = legacy.index("// VOX_MSL_PRECISION_END") + len("// VOX_MSL_PRECISION_END\n")
    legacy = legacy[:begin] + legacy[end:]
    legacy = legacy.replace("\n\n\nnamespace SkContexts", "\n\nnamespace SkContexts")
    legacy = legacy.replace("    std::string fullPrecision = vox_promote_msl_precision(msl);",
        '    std::string fullPrecision = std::regex_replace(std::string(msl),\n'
        '        std::regex(R"(\\bhalf([234](x[234])?)?\\b)"), "float$1");\n'
        '    fullPrecision = std::regex_replace(fullPrecision, std::regex(R"(([0-9])h\\b)"), "$1f");')
    assert hashlib.sha256(legacy.encode()).hexdigest() == LEGACY_MSL_SHA256
    (source / msl_name).write_text(legacy)
    prepare_precision_patch(source, archive, patch)
    assert patched == {name: (source / name).read_bytes() for name in PATCH_INPUTS}
    # Reject partial and unknown inputs before touching any source file.
    for replacement in [original[msl_name], b"unrecognized dependency\n"]:
        (source / msl_name).write_bytes(replacement)
        before = {name: (source / name).read_bytes() for name in PATCH_INPUTS}
        try:
            prepare_precision_patch(source, archive, patch)
        except SystemExit:
            pass
        else:
            raise AssertionError("Unauthenticated dependency accepted")
        assert before == {name: (source / name).read_bytes() for name in PATCH_INPUTS}
    compiler = shutil.which("clang++") or "c++"
    for mode, flags in [("release", ["-O2"]),
                        ("sanitized", ["-O1", "-g", "-fsanitize=address,undefined"])]:
        executable = output / mode
        subprocess.run([compiler, "-std=c++20", "-Wall", "-Wextra", "-Werror", *flags,
                        "-I" + str(output), str(repo / "tools/native_graphite_msl_precision_test.cpp"),
                        "-o", str(executable)], check=True)
        subprocess.run([str(executable)], check=True)
    print("Pristine install, idempotency, legacy upgrade and rejection checks passed", flush=True)


if __name__ == "__main__":
    main()
