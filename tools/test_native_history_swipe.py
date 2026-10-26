#!/usr/bin/env python3
"""Check macOS history gesture handling through tools/run_memory_bounded.py."""
from datetime import datetime
from pathlib import Path
import subprocess


def main():
    repo = Path(__file__).resolve().parent.parent
    output = repo / "Build" / ("history-swipe-native-" + datetime.now().strftime("%Y%m%d-%H%M%S-%f"))
    output.mkdir(parents=True)
    binary = output / "history-swipe-test"
    commands = [
        ["clang", "-fobjc-arc", "-fblocks", "-Wall", "-Wextra", "-Werror",
         "-framework", "Cocoa", str(repo / "tools/native_history_swipe_test.m"),
         "-o", str(binary)],
        [str(binary)],
    ]
    with (output / "checks.log").open("w") as log:
        for command in commands:
            log.write(repr(command) + "\n")
            log.flush()
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
            log.write(f"exit_code={result.returncode}\n")
            log.flush()
            if result.returncode:
                print((output / "checks.log").read_text(), end="")
                raise SystemExit(result.returncode)
    print((output / "checks.log").read_text(), end="")


if __name__ == "__main__":
    main()
