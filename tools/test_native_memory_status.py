#!/usr/bin/env python3
"""Compile and run the V/UI2 RAM status accounting and timer lifecycle tests."""
import argparse
import hashlib
import os
import json
import pathlib
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    binary = output / "tests"
    command = ["sh", "tools/test_address_bar.sh", "-memory-limit", "10G",
               "-skip-running", "-o", str(binary)]
    sources = [root / name for name in ["memorymgmt/memory_status.v", "memorymgmt/memory_status_test.v",
                                      "tools/ui2/embedded_browser_darwin.v"]]
    result = {"compile_command": command, "started_unix": time.time(),
              "source_sha256": {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
                                for path in sources}}
    with (output / "compile.log").open("w") as log:
        result["actual_compiler_exit_code"] = subprocess.run(
            command, cwd=root, env=dict(os.environ, VOX_CHROME_TEST_FILE="memorymgmt/memory_status_test.v"), stdout=log, stderr=subprocess.STDOUT).returncode
    if result["actual_compiler_exit_code"] == 0:
        with (output / "run.log").open("w") as log:
            try:
                result["actual_test_exit_code"] = subprocess.run(
                    [sys.executable, str(root / "tools/run_memory_bounded.py"),
                     "--limit-gib", "3", "--lock", str(output / "run.lock"),
                     "--report", str(output / "run-guard.json"), "--", str(binary)],
                    cwd=root, stdout=log, stderr=subprocess.STDOUT, timeout=30).returncode
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
