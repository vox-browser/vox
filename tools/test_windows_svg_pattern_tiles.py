#!/usr/bin/env python3
"""Check mixed bitmap and non-scaling SVG pattern tiles in Windows windows."""

import argparse
from functools import partial
import hashlib
import json
from pathlib import Path
import tempfile

from test_linux_browser import check_svg_pattern_tile_image_browser, run


def run_guarded_capture(guard, command, env, log_path):
    env = dict(env, APPDATA=env["XDG_CONFIG_HOME"], LOCALAPPDATA=env["XDG_CACHE_HOME"],
               TEMP=env["TMPDIR"], TMP=env["TMPDIR"])
    stdout = log_path.with_suffix(".stdout")
    stderr = log_path.with_suffix(".stderr")
    for stream in (stdout, stderr):
        stream.unlink(missing_ok=True)
    try:
        report = run([str(guard), "240000", "3072", str(stdout), str(stderr), *command],
                     env=env, log_path=log_path.with_suffix(".guard.json"), timeout=260)
    finally:
        log = "\n".join(stream.read_text(encoding="utf-8", errors="replace")
                        for stream in (stdout, stderr) if stream.exists())
        log_path.write_text(log, encoding="utf-8")
    receipt = json.loads(report)
    assert receipt["child_exit_code"] == 0 and not receipt["timed_out"], receipt
    return log


def input_hashes(binary, guard):
    return {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in (binary, guard, *sorted(binary.parent.glob("*.dll")))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path, help="Windows Vox executable")
    parser.add_argument("--guard", type=Path, required=True, help="Windows job-object guard")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    binary, guard = args.binary.resolve(), args.guard.resolve()
    artifacts = args.output.resolve()
    artifacts.mkdir(parents=True, exist_ok=True)
    inputs = input_hashes(binary, guard)
    (artifacts / "windows-inputs.json").write_text(json.dumps(inputs, indent=2) + "\n", encoding="utf-8")
    with tempfile.TemporaryDirectory(prefix="vox-svg-pattern-tile-") as temporary:
        check_svg_pattern_tile_image_browser(binary, artifacts, temporary,
                                             partial(run_guarded_capture, guard))
    assert input_hashes(binary, guard) == inputs, "Windows browser or guard inputs changed during capture"


if __name__ == "__main__":
    main()
