#!/usr/bin/env python3
"""Check mixed bitmap and non-scaling SVG pattern tiles in Windows windows."""

import argparse
from functools import partial
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

from test_linux_browser import (check_svg_equivalent_pattern_tiles, check_svg_hidden_pattern_tiles_browser,
                                check_svg_interleaved_pattern_tiles, check_svg_pattern_tile_image_browser)


def run_guarded_capture(guard, command, env, log_path):
    env = dict(env, APPDATA=env["XDG_CONFIG_HOME"], LOCALAPPDATA=env["XDG_CACHE_HOME"],
               TEMP=env["TMPDIR"], TMP=env["TMPDIR"])
    stdout = log_path.with_suffix(".stdout")
    stderr = log_path.with_suffix(".stderr")
    guard_log = log_path.with_suffix(".guard.json")
    for stream in (stdout, stderr):
        stream.unlink(missing_ok=True)
    try:
        # The Win32 guard launches an inheriting child. Use a file for its
        # receipt so Python does not have to wait for EOF on a capture pipe.
        with guard_log.open("wb") as output:
            result = subprocess.run(
                [str(guard), "240000", "3072", str(stdout), str(stderr), *command],
                env=env, stdout=output, stderr=subprocess.STDOUT, timeout=260,
            )
    finally:
        log = "\n".join(stream.read_text(encoding="utf-8", errors="replace")
                        for stream in (stdout, stderr) if stream.exists())
        log_path.write_text(log, encoding="utf-8")
    report = guard_log.read_text(encoding="utf-8", errors="replace")
    if result.returncode:
        raise RuntimeError(f"Windows guard exited {result.returncode}: {report}")
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
    parser.add_argument("--nested", action="store_true", help="check nested bitmap and vector SVG patterns")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    binary, guard = args.binary.resolve(), args.guard.resolve()
    artifacts = args.output.resolve()
    artifacts.mkdir(parents=True, exist_ok=True)
    inputs = input_hashes(binary, guard)
    (artifacts / "windows-inputs.json").write_text(json.dumps(inputs, indent=2) + "\n", encoding="utf-8")
    with tempfile.TemporaryDirectory(prefix="vox-svg-pattern-tile-") as temporary:
        capture = partial(run_guarded_capture, guard)
        check_svg_pattern_tile_image_browser(binary, artifacts, temporary, capture, nested=args.nested)
        if args.nested:
            check_svg_pattern_tile_image_browser(binary, artifacts, temporary, capture, shared=True)
            check_svg_hidden_pattern_tiles_browser(binary, artifacts, temporary, capture)
            check_svg_equivalent_pattern_tiles(binary, artifacts, temporary, capture)
            check_svg_interleaved_pattern_tiles(binary, artifacts, temporary, capture)
    assert input_hashes(binary, guard) == inputs, "Windows browser or guard inputs changed during capture"


if __name__ == "__main__":
    main()
