#!/usr/bin/env python3
"""Exercise the production idle dispatcher without a browser window."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    output = (args.output or repo / "Build/native-idle-memory-test").resolve()
    output.mkdir(parents=True, exist_ok=True)
    host = repo / "native_capture_darwin.m"
    test = repo / "tools/native_idle_memory_test.m"
    header = repo / "native/include/native_layer_presentation_darwin.h"
    pins = {str(p): digest(p) for p in (host, test, header, Path(__file__))}
    source = host.read_text()
    begin = "// Run after the native draw has unwound."
    end = "static void native_initialize_css_filter_renderer(void)"
    assert source.count(begin) == source.count(end) == 1
    fragment = source[source.index(begin):source.index(end)]
    fragment_path = output / "production-idle-memory.inc"
    fragment_path.write_text(fragment)
    executable = output / "native_idle_memory_test"
    command = ["clang", "-O2", "-fobjc-arc", "-fblocks",
               "-DLADYBIRD_V_HAS_SKIA_TEXT",
               '-DVOX_NATIVE_MEMORY_FRAGMENT="' + str(fragment_path) + '"',
               str(test), "-framework", "Cocoa", "-framework", "CoreImage",
               "-framework", "QuartzCore", "-framework", "IOSurface", "-o", str(executable)]
    result = {"source_sha256": pins, "fragment_sha256": digest(fragment_path),
              "compile_command": command, "actual_test_exit_code": None}
    with (output / "compile.log").open("w") as log:
        result["actual_compiler_exit_code"] = subprocess.run(
            command, stdout=log, stderr=subprocess.STDOUT).returncode
    status = result["actual_compiler_exit_code"]
    if status == 0:
        with (output / "test.log").open("w") as log:
            status = subprocess.run([str(executable)], stdout=log,
                                    stderr=subprocess.STDOUT).returncode
        result["actual_test_exit_code"] = status
        result["binary_sha256"] = digest(executable)
    result["inputs_unchanged"] = all(digest(Path(p)) == sha for p, sha in pins.items())
    result["actual_outer_exit_code"] = status or (0 if result["inputs_unchanged"] else 1)
    (output / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))
    return result["actual_outer_exit_code"]


if __name__ == "__main__":
    sys.exit(main())
