#!/usr/bin/env python3
"""Stage V's native codec modules with Linux archives, without editing V."""

import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

from prepare_http_compat import compiler_vlib, write_if_changed


def patch_module(package, source):
    if package == "stbi":
        source = source.replace("import os\n", "import os as _\n")
    if package in {"gg", "net/openssl"}:
        source = re.sub(r'u64\(usize\((voidptr\([^()]*\))\)\)', r'u64(\1)', source)
        source = re.sub(r'\busize\(', 'uint(', source)
    if package == "net/openssl":
        source = re.sub(r'(?m)^(\s*)unsafe \{\n\s*mut ptr_base := bytes\n',
                        r'\1mut ptr_base := unsafe { bytes }\n\1unsafe {\n', source)
    return source


def stage_module(source, target, package):
    """Keep compiler assets beside patched sources, without changing the compiler."""
    expected = set()
    for path in source.rglob("*"):
        if not path.is_file() or path.name.endswith("_test.v"):
            continue
        relative = path.relative_to(source)
        expected.add(relative)
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        if path.suffix == ".v":
            write_if_changed(destination, patch_module(package, path.read_text()))
        elif not destination.is_symlink() or destination.resolve() != path.resolve():
            destination.unlink(missing_ok=True)
            destination.symlink_to(path.resolve())
    if target.exists():
        for path in sorted(target.rglob("*"), reverse=True):
            if path.is_dir() and not path.is_symlink():
                if not any(path.iterdir()):
                    path.rmdir()
            elif path.relative_to(target) not in expected:
                path.unlink()


def main():
    repo = Path(__file__).resolve().parent.parent
    work = repo / "Build/linux/native"
    work.mkdir(parents=True, exist_ok=True)
    vlib = compiler_vlib(sys.argv[1], work)
    compiler = os.environ.get("CC", "cc")
    modules = repo / "Build/linux/modules"
    for package, directory, name in [("stbi", "stb_image", "stbi"), ("json", "cJSON", "cJSON")]:
        thirdparty = vlib.parent / "thirdparty" / directory
        if not (vlib / package).is_dir() or not (thirdparty / (name + ".c")).is_file():
            # Current V removed the cJSON-based `json` module (json2 replaces
            # it); Vox does not import it, so skip packages the compiler lacks.
            shutil.rmtree(modules / package, ignore_errors=True)
            continue
        digest = hashlib.sha256(subprocess.check_output([compiler, "--version"]))
        digest.update(Path(__file__).read_bytes())
        for source in sorted(thirdparty.glob("*.h")) + [thirdparty / (name + ".c")]:
            digest.update(source.read_bytes())
        archive = work / (name + ".a")
        stamp = archive.with_suffix(".sha256")
        if not archive.is_file() or not stamp.is_file() or stamp.read_text() != digest.hexdigest():
            object_file = work / (name + ".o")
            subprocess.run([compiler, "-O2", "-fPIC", "-c", str(thirdparty / (name + ".c")),
                            "-o", str(object_file)], check=True)
            subprocess.run(["ar", "rcs", str(archive), str(object_file)], check=True)
            stamp.write_text(digest.hexdigest())
        for source in (vlib / package).rglob("*.v"):
            if source.name.endswith("_test.v"):
                continue
            text = patch_module(package, source.read_text()).replace(
                f"#flag @VEXEROOT/thirdparty/{directory}/{name}.o", f"#flag {archive}")
            target = modules / package / source.relative_to(vlib / package)
            target.parent.mkdir(parents=True, exist_ok=True)
            write_if_changed(target, text)
    for package in ["gg", "net/openssl"]:
        stage_module(vlib / package, modules / package, package)
    print(modules)


if __name__ == "__main__":
    main()
