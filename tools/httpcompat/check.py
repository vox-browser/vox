#!/usr/bin/env python3
"""Compile and exercise the staged HTTP header adapter, including RU filtering."""

import os
from pathlib import Path
import shutil
import subprocess
import sys


def main():
    repo = Path(__file__).resolve().parents[2]
    compiler = sys.argv[1] if len(sys.argv) > 1 else os.environ.get(
        "V_BIN", shutil.which("v") or str(Path.home() / "code/v/v"))
    modules = subprocess.check_output(
        [sys.executable, str(repo / "tools/prepare_http_compat.py"), compiler], text=True).strip()
    binary = repo / "Build/v/httpcompat/check_headers"
    subprocess.run([compiler, "-enable-globals", "-path",
                    f"{modules}|{repo}|@vmodules|@vlib", "-o", str(binary),
                    str(repo / "tools/httpcompat/check_headers.v")], cwd=repo, check=True)
    subprocess.run([str(binary)], cwd=repo, check=True)


if __name__ == "__main__":
    main()
