#!/usr/bin/env python3
"""Compile and run the production tab metadata codec with FastC.

The isolated module contains byte-for-byte production declarations, codec and
tests. It needs no UI, fonts or Skia, so CI can catch JSON/compiler integration
failures before building the native dependencies. No implementation is stubbed
or rewritten. Run this driver under tools/run_memory_bounded.py.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from prepare_prealloc_runtime import prepare as prepare_prealloc_runtime


SOURCES = (
    "browsertabs/metadata.v",
    "browsertabs/codec.v",
    "browsertabs/color_codec_test.v",
)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--v", default=os.environ.get("V_BIN") or shutil.which("v"))
    parser.add_argument("--cc", default=os.environ.get("CC", "clang"))
    parser.add_argument("--gc", choices=["boehm", "prealloc", "none"], default="boehm")
    args = parser.parse_args()
    if not args.v:
        parser.error("provide --v or set V_BIN to the supported current V compiler")
    compiler = Path(shutil.which(args.v) or args.v).resolve()
    if not compiler.is_file():
        parser.error(f"V compiler does not exist: {compiler}")
    repo = Path(__file__).resolve().parent.parent
    source_bytes = {path: (repo / path).read_bytes() for path in SOURCES}
    hashes = {path: digest(data) for path, data in source_bytes.items()}
    compiler_hash = digest(compiler.read_bytes())
    version = subprocess.check_output(
        [str(compiler), "-memory-limit", "10G", "version"], text=True).strip()
    output_root = repo / "Build/linux/tests" / args.gc
    output_root.mkdir(parents=True, exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix="run-tab-codec-", dir=output_root))
    identity = {"backend": "fastc", "gc": args.gc, "v": version,
                "compiler_sha256": compiler_hash, "source_sha256": hashes}
    (output / "inputs.json").write_text(json.dumps(identity, indent=2) + "\n")
    print(json.dumps(identity, sort_keys=True), flush=True)
    print(f"Logs: {output}", flush=True)
    with tempfile.TemporaryDirectory(prefix="vox-tab-codec-") as temporary:
        isolated = Path(temporary)
        for path, data in source_bytes.items():
            target = isolated / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        (isolated / "v.mod").write_text("Module { name: 'tab_metadata_codec' }\n")
        module_paths = [str(isolated)]
        selected_compiler = compiler
        if args.gc == "prealloc":
            runtime = prepare_prealloc_runtime(compiler)
            selected_compiler = runtime / "compiler/v"
            module_paths.append(str(runtime))
        module_paths.append("@vlib")
        environment = dict(os.environ, V_C_ERROR_BUG_REPORT_DISABLED="1",
                           V_MACOS_V3_NO_FALLBACK="1")
        binary = isolated / "tab-codec-test"
        command = [str(selected_compiler), "-b", "fastc", "-memory-limit", "10G",
                   "-enable-globals", "-cc", args.cc,
                   # The full browser's native headers include math.h. Supply
                   # its declarations for json2's floating-point codec in this
                   # isolated graph as well (including C.ldexp).
                   "-cflags", "-include math.h",
                   "-gc", "none" if args.gc == "prealloc" else args.gc,
                   "-path", "|".join(module_paths)]
        if args.gc == "prealloc":
            command += ["-prealloc"]
        elif args.gc == "boehm":
            command += ["-d", "dynamic_boehm"]
        command += ["-o", str(binary), str(isolated / SOURCES[-1])]
        try:
            result = subprocess.run(command, cwd=selected_compiler.parent,
                                    env=environment, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT)
            (output / "compile.log").write_bytes(result.stdout)
            print(result.stdout.decode(errors="replace"), end="", flush=True)
            if result.returncode:
                return result.returncode
            result = subprocess.run(
                [sys.executable, str(repo / "tools/run_memory_bounded.py"),
                 "--limit-gib", "3", "--lock", str(output / "runtime.lock"),
                 "--report", str(output / "runtime.json"), "--", str(binary)],
                cwd=isolated, env=environment, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT)
            (output / "runtime.log").write_bytes(result.stdout)
            print(result.stdout.decode(errors="replace"), end="", flush=True)
            return result.returncode
        finally:
            changed = [path for path, expected in hashes.items()
                       if digest((repo / path).read_bytes()) != expected
                       or digest((isolated / path).read_bytes()) != expected]
            if digest(compiler.read_bytes()) != compiler_hash:
                changed.append("V compiler")
            if changed:
                raise SystemExit("Codec inputs changed during validation: " + ", ".join(changed))
            print(json.dumps({"backend": "fastc", "gc": args.gc,
                              "source_files_verified": len(hashes)}, sort_keys=True), flush=True)


if __name__ == "__main__":
    raise SystemExit(main())
