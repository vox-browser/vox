#!/usr/bin/env python3
"""Stage V's native codec modules with Linux archives, without editing V."""

import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys

from prepare_http_compat import compiler_vlib, write_if_changed


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
            text = source.read_text().replace(
                f"#flag @VEXEROOT/thirdparty/{directory}/{name}.o", f"#flag {archive}")
            target = modules / package / source.relative_to(vlib / package)
            target.parent.mkdir(parents=True, exist_ok=True)
            write_if_changed(target, text)
    print(modules)


if __name__ == "__main__":
    main()
