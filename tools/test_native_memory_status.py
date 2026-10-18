#!/usr/bin/env python3
"""Compile and run the no-window native RAM-footer lifecycle/timer test."""
import argparse
import hashlib
import json
import pathlib
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    clang = subprocess.check_output(["xcrun", "--find", "clang"], text=True).strip()
    sdk = subprocess.check_output(["xcrun", "--show-sdk-path"], text=True).strip()
    binary = output / "tests"
    command = [clang, "-isysroot", sdk, "-std=c11", "-O2", "-fblocks", "-fobjc-arc",
               "-Wall", "-Wextra", "-Werror", str(root / "tools/native_memory_status_test.m"),
               "-framework", "Cocoa", "-framework", "QuartzCore", "-framework", "CoreText",
               "-o", str(binary)]
    sources = [root / name for name in ["native_memory_status_darwin.m",
                                      "tools/native_memory_status_test.m"]]
    result = {"compile_command": command, "started_unix": time.time(),
              "source_sha256": {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
                                for path in sources}}
    with (output / "compile.log").open("w") as log:
        result["actual_compiler_exit_code"] = subprocess.run(
            command, cwd=root, stdout=log, stderr=subprocess.STDOUT).returncode
    if result["actual_compiler_exit_code"] == 0:
        with (output / "run.log").open("w") as log:
            try:
                result["actual_test_exit_code"] = subprocess.run(
                    [str(binary)], cwd=root, stdout=log, stderr=subprocess.STDOUT,
                    timeout=30).returncode
            except subprocess.TimeoutExpired:
                result["test_timed_out"] = True
        result["binary_sha256"] = hashlib.sha256(binary.read_bytes()).hexdigest()
    result["finished_unix"] = time.time()
    result["source_pins_unchanged"] = all(
        hashlib.sha256(path.read_bytes()).hexdigest() == result["source_sha256"][str(path)]
        for path in sources)
    result["actual_controller_exit_code"] = int(
        result["actual_compiler_exit_code"] != 0
        or result.get("actual_test_exit_code", 1) != 0
        or not result["source_pins_unchanged"])
    (output / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))
    return result["actual_controller_exit_code"]


if __name__ == "__main__":
    raise SystemExit(main())
