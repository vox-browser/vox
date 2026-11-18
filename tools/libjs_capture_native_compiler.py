#!/usr/bin/env python3
"""Run Clang for LibJS and retain the generated C beside its library receipt."""

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


CLANG = "/usr/bin/clang"
C_FLAGS = ("-O2", "-std=c11", "-fno-strict-aliasing")
CAPTURE_DIR = "VOX_LIBJS_NATIVE_CAPTURE_DIR"


def digest(path):
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def capture_compile(arguments, directory):
    if sys.platform != "darwin":
        raise ValueError("Native compiler capture requires macOS")
    if (len(arguments) != 7 or tuple(arguments[:4]) != (*C_FLAGS, "-dynamiclib")
            or arguments[5] != "-o"):
        raise ValueError("Expected the LibJS macOS native compiler arguments")
    source, output = Path(arguments[4]), Path(arguments[6])
    if source.name != "code.c" or output.name != "code.dylib":
        raise ValueError("Expected the LibJS code.c and code.dylib paths")
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".capture-", dir=directory) as scratch:
        stage = Path(scratch) / "batch"
        stage.mkdir()
        saved = stage / "code.c"
        shutil.copyfile(source, saved)
        source_sha = digest(saved)
        subprocess.run([CLANG, *arguments], check=True)
        if digest(source) != source_sha:
            raise ValueError("Generated C changed during compilation")
        library_sha = digest(output)
        receipt = dict(source_sha256=source_sha, library_sha256=library_sha, c_flags=list(C_FLAGS))
        (stage / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
        target = directory / library_sha
        try:
            stage.rename(target)
        except OSError:
            # An identical compile can publish first. Reuse only its verified capture.
            if (not target.is_dir() or json.loads((target / "receipt.json").read_bytes()) != receipt
                    or digest(target / "code.c") != source_sha):
                raise


def main():
    location = os.environ.get(CAPTURE_DIR)
    if not location:
        print(f"Set {CAPTURE_DIR} to a private capture directory", file=sys.stderr)
        return 1
    try:
        capture_compile(sys.argv[1:], Path(location))
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"libjs_capture_native_compiler: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
