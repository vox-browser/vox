#!/usr/bin/env python3
"""Check macOS history gesture handling (browserwindow) under the memory guard."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def main():
    repo = Path(__file__).resolve().parent.parent
    compiler = os.environ.get("V_BIN") or shutil.which("v") or str(Path.home() / "code/v/v")
    with tempfile.TemporaryDirectory(prefix="history-swipe-") as scratch:
        command = [sys.executable, str(repo / "tools/run_memory_bounded.py"), "--limit-gib", "3",
                   "--lock", str(Path(scratch) / "run.lock"), "--report", str(Path(scratch) / "run.json"),
                   "--", compiler, "-memory-limit", "10G", "test", "browserwindow/history_swipe_darwin_test.v"]
        raise SystemExit(subprocess.run(command, cwd=repo).returncode)


if __name__ == "__main__":
    main()
