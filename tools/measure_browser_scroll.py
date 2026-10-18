#!/usr/bin/env python3
"""Measure settled native wheel handling and paint replay, with optional sampling.

Use identical URL, viewport, frame count and cache template for comparisons.
Frames include normal JavaScript, layout, paint and GC work inside the browser's
frame callback. Cocoa layer publication, display-clock waits and GPU execution
are outside the timed callback.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import statistics
import subprocess
import time

REPO = Path(__file__).resolve().parents[1]
FRAME = re.compile(r"^Vox scroll frame: (\d+) (.*)$", re.MULTILINE)


def summarize(log, expected_frames):
    rows = []
    for number, fields in FRAME.findall(log):
        row = {key: float(value) for key, value in
               (field.split("=", 1) for field in fields.split())}
        row["frame"] = int(number)
        rows.append(row)
    if [row["frame"] for row in rows] != list(range(expected_frames)):
        raise ValueError("Missing, duplicated or out-of-order scroll frames")
    moved = [row for row in rows if row["before_y"] != row["after_y"]]
    if not moved:
        raise ValueError("No measured wheel event scrolled the viewport")

    def distribution(selected):
        result = {"frames": len(selected)}
        for key in ("wheel_us", "prepare_us", "replay_us", "total_us", "instructions", "allocated_kb", "collections"):
            if not all(key in row for row in selected):
                continue
            values = sorted(row[key] for row in selected)
            result[key] = {"median": statistics.median(values),
                           "p95": values[min(len(values) - 1, int(len(values) * .95))],
                           "max": values[-1], "sum": sum(values)}
        return result

    return {"all": distribution(rows), "moving": distribution(moved), "rows": rows}


def compare(before, after):
    for key in ("url", "viewport", "raster_mode", "cache_sha256"):
        if before[key] != after[key]:
            raise ValueError(f"Scroll comparison changed {key}")
    trace = lambda result: [(row["before_y"], row["after_y"], row["commands"])
                            for row in result["rows"]]
    if trace(before) != trace(after):
        raise ValueError("Scroll positions or paint-command counts changed between runs")
    old = before["moving"]["total_us"]["median"]
    new = after["moving"]["total_us"]["median"]
    return {"moving_callback_reduction_percent": (old - new) / old * 100,
            "before_median_us": old, "after_median_us": new}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path,
                        default=REPO / "Build/v/Vox.app/Contents/MacOS/Vox")
    parser.add_argument("--url", default="https://www.wikipedia.org/")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--cache-template", type=Path)
    parser.add_argument("--frames", type=int, default=120)
    parser.add_argument("--width", type=int, default=1024)
    parser.add_argument("--height", type=int, default=768)
    parser.add_argument("--timeout", type=float, default=180)
    parser.add_argument("--sample-seconds", type=int, default=0)
    parser.add_argument("--settle-seconds", type=float, default=1,
                        help="Quiet period after loading settles before the first wheel event")
    parser.add_argument("--capture", action="store_true",
                        help="Also capture final pixels using the browser's logical-pixel screenshot mode")
    parser.add_argument("--compare-to", type=Path, help="Compare against a previous summary with identical input and scroll trace")
    parser.add_argument("--insert-library", type=Path, action="append", default=[],
                        help="Inject a dylib into the browser (repeatable), e.g. the offline "
                             "network guard or tools/gc_allocation_sampler.c. macOS strips DYLD_* "
                             "from this interpreter's own environment, so pass libraries here")
    parser.add_argument("--env", action="append", default=[], metavar="NAME=VALUE",
                        help="Extra browser environment variable (repeatable)")
    parser.add_argument("--trigger-file", type=Path,
                        help="Create this file once --trigger-frame has been logged")
    parser.add_argument("--trigger-frame", type=int, default=5)
    args = parser.parse_args()
    if args.frames < 1:
        parser.error("--frames must be positive")
    if args.width < 1 or args.height < 1 or args.timeout <= 0 or args.sample_seconds < 0:
        parser.error("Viewport and timeout must be positive; sample duration cannot be negative")
    if any("=" not in item for item in args.env):
        parser.error("--env expects NAME=VALUE")
    args.output.mkdir(parents=True, exist_ok=False)
    binary = args.binary.resolve()
    cache = args.output / "cache"
    if args.cache_template:
        shutil.copytree(args.cache_template, cache)
    else:
        cache.mkdir()
    shutil.rmtree(cache / "snapshots", ignore_errors=True)
    cache_digest = hashlib.sha256()
    for path in sorted(cache.rglob("*")):
        if path.is_file():
            cache_digest.update(str(path.relative_to(cache)).encode() + b"\0" + path.read_bytes())
    env = dict(os.environ, VOX_PROFILE_SCROLL="1",
               VOX_SCROLL_PROFILE_FRAMES=str(args.frames),
               VOX_SCROLL_PROFILE_SETTLE_MS=str(max(1, int(args.settle_seconds * 1000))),
               LADYBIRD_CACHE_DIR=str(cache.resolve()), NO_PROXY="localhost,127.0.0.1")
    env.pop("LADYBIRD_ENABLE_SNAPSHOT_CACHE", None)
    env.pop("LADYBIRD_SCREENSHOT_DELAY_SECONDS", None)
    if args.capture:
        env["LADYBIRD_SCREENSHOT_DELAY_SECONDS"] = "0"
    library = binary.parent / "libLadybirdVSkiaText.dylib"
    if not library.is_file() and len(binary.parents) > 3:
        library = binary.parents[3] / "libLadybirdVSkiaText.dylib"
    library_digest = hashlib.sha256(library.read_bytes()).hexdigest() if library.is_file() else None
    if library.is_file():
        env["DYLD_LIBRARY_PATH"] = str(library.parent)
    env.update(item.split("=", 1) for item in args.env)
    if args.insert_library:
        env["DYLD_INSERT_LIBRARIES"] = ":".join(str(path.resolve()) for path in args.insert_library)
    if args.trigger_file:
        args.trigger_file.unlink(missing_ok=True)
    trigger_line = f"Vox scroll frame: {args.trigger_frame} "
    command = [str(binary), "--enable-javascript", "--window-width", str(args.width),
               "--window-height", str(args.height + 80)]
    if args.capture:
        command += ["--screenshot", str((args.output / "window.png").resolve())]
    command.append(args.url)
    digest = hashlib.sha256(binary.read_bytes()).hexdigest()
    log_path = args.output / "browser.log"
    sample = None
    with log_path.open("w") as output:
        process = subprocess.Popen(command, cwd=REPO, env=env, stdout=output,
                                   stderr=subprocess.STDOUT)
        started = time.monotonic()
        try:
            while process.poll() is None:
                if time.monotonic() - started > args.timeout:
                    raise TimeoutError(f"Scroll benchmark timed out: {log_path}")
                if args.trigger_file and not args.trigger_file.exists() and trigger_line in log_path.read_text():
                    args.trigger_file.touch()
                if args.sample_seconds and sample is None and "Vox scroll frame:" in log_path.read_text():
                    sample = subprocess.Popen(["sample", str(process.pid), str(args.sample_seconds),
                                               "1", "-file", str(args.output / "sample.txt")],
                                              stdout=output, stderr=subprocess.STDOUT)
                time.sleep(.05)
            if process.returncode:
                raise RuntimeError(f"Browser exited {process.returncode}: {log_path}")
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            if sample:
                sample.wait(timeout=args.sample_seconds + 10)
    if digest != hashlib.sha256(binary.read_bytes()).hexdigest():
        raise RuntimeError("Browser executable changed during measurement")
    if library_digest and library_digest != hashlib.sha256(library.read_bytes()).hexdigest():
        raise RuntimeError("Native replay library changed during measurement")
    result = {"command": command, "binary_sha256": digest,
              "library_sha256": library_digest,
              "cache_sha256": cache_digest.hexdigest(),
              "url": args.url, "viewport": [args.width, args.height],
              "raster_mode": "logical-pixel screenshot" if args.capture else "interactive window backing scale",
              "endpoint": "native wheel dispatch through replay, including synchronous GPU waits; excludes Cocoa layer publication, vsync and idle work",
              **summarize(log_path.read_text(), args.frames)}
    (args.output / "summary.json").write_text(json.dumps(result, indent=2) + "\n")
    if args.compare_to:
        result["comparison"] = compare(json.loads(args.compare_to.read_text()), result)
        (args.output / "summary.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({key: value for key, value in result.items() if key != "rows"}, indent=2))


if __name__ == "__main__":
    main()
