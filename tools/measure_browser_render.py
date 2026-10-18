#!/usr/bin/env python3
"""Compare native first-document-frame times using identical initial cache bytes.

Each sample launches a fresh process and copies the resource/page cache. Raster
snapshot reuse is disabled. Samples alternate before/after, and native paint
timers exclude the later screenshot and teardown. The two variants may use the
same executable with different arguments to isolate a runtime policy change.
Background network refresh remains enabled; only the initial cache is frozen.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import statistics
import subprocess
import time

from measure_browser_instructions import (
    VOX_CHROME_HEIGHT,
    crop_document_viewport,
    fresh_vox_cache,
    parse_native_counters,
    stop_process,
)

REPO = Path(__file__).resolve().parents[1]
TIMING = re.compile(r"^Ladybird V timing: (.*?) (\d+) ms$", re.MULTILINE)
SCRIPTING = re.compile(
    r"^Ladybird V scripting: enabled=(true|false) runtime=(true|false) "
    r"sources=(\d+) source_bytes=(\d+) preloaded_scripts=(\d+)$", re.MULTILINE)


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def native_summary(log):
    # Keep the first page's values: a background network refresh may produce
    # another installation before screenshot capture on a slow machine.
    timings = {}
    for label, value in TIMING.findall(log):
        timings.setdefault(label, int(value))
    return timings


def scripting_summary(log):
    match = SCRIPTING.search(log)
    if match is None:
        return None
    enabled, runtime, sources, source_bytes, preloaded = match.groups()
    return {"enabled": enabled == "true", "runtime": runtime == "true",
            "sources": int(sources), "source_bytes": int(source_bytes),
            "preloaded_scripts": int(preloaded)}


def run_sample(args, label, index, binary, extra):
    prefix = args.output / f"{label}-{index}"
    window = Path(str(prefix) + ".window.png")
    screenshot = Path(str(prefix) + ".png")
    log_path = Path(str(prefix) + ".log")
    binary_hash = sha256(binary)
    window.unlink(missing_ok=True)
    with fresh_vox_cache(args.cache_template, args.output) as (cache, digest):
        # A cached screenshot is not a rendered document. Discard raster state
        # even when the input template accidentally contains old snapshots.
        shutil.rmtree(cache / "snapshots", ignore_errors=True)
        env = dict(os.environ, LADYBIRD_CACHE_DIR=str(cache),
                   LADYBIRD_DEBUG_TIMING="1", VOX_PROFILE_INSTRUCTIONS="1",
                   LADYBIRD_SCREENSHOT_DELAY_SECONDS="0")
        env.pop("LADYBIRD_ENABLE_SNAPSHOT_CACHE", None)
        env.pop("GC_PRINT_STATS", None)
        # A preserved pre-change executable can keep its native replay library
        # beside it instead of loading a newly rebuilt canonical library.
        library_name = "libLadybirdVSkiaText.dylib"
        library = binary.parent / library_name
        if not library.is_file() and len(binary.parents) > 3:
            library = binary.parents[3] / library_name
        if library.is_file():
            env["DYLD_LIBRARY_PATH"] = str(library.parent)
        library_hash = sha256(library) if library.is_file() else None
        command = [str(binary), *extra, "--window-width", str(args.width),
                   "--window-height", str(args.height + VOX_CHROME_HEIGHT),
                   "--screenshot", str(window), args.url]
        with log_path.open("w") as log:
            started = time.monotonic()
            process = subprocess.Popen(command, cwd=REPO, env=env, stdout=log,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            try:
                code = process.wait(timeout=args.timeout)
            finally:
                stop_process(process)
            capture_ms = (time.monotonic() - started) * 1000
        log = log_path.read_text()
        if code or not window.is_file():
            raise RuntimeError(f"{label} sample {index} failed (exit {code}); see {log_path}")
        if sha256(binary) != binary_hash or (library_hash and sha256(library) != library_hash):
            raise RuntimeError("Measured executable or replay library changed during capture")
        timings = native_summary(log)
        if "navigation_to_first_document_paint" not in timings:
            raise RuntimeError(f"Missing first-document-frame timer; see {log_path}")
        crop_document_viewport(window, screenshot, args.width, args.height)
        result = {
            "variant": label, "sample": index, "command": command,
            "binary_sha256": binary_hash, "cache_sha256": digest,
            "library_sha256": library_hash,
            "load_average": os.getloadavg(),
            "timings_ms": timings, "native": parse_native_counters(log),
            "scripting": scripting_summary(log),
            "document_installations_before_capture": sum(
                label == "parse_document" for label, _ in TIMING.findall(log)),
            "process_launch_to_capture_exit_ms": capture_ms,
            "screenshot": str(screenshot), "screenshot_sha256": sha256(screenshot),
            "log": str(log_path),
            "javascript_diagnostics": [line for line in log.splitlines()
                                       if line.startswith("Ladybird V scripting:")],
        }
        Path(str(prefix) + ".json").write_text(json.dumps(result, indent=2) + "\n")
        print(json.dumps({"variant": label, "sample": index,
                          "timings_ms": timings}), flush=True)
        return result


def summarize(results):
    if len({row["cache_sha256"] for row in results}) != 1:
        raise RuntimeError("Initial cache inputs changed between samples")
    variants = {}
    for label in ("before", "after"):
        rows = [row for row in results if row["variant"] == label]
        if len({(row["binary_sha256"], row["library_sha256"]) for row in rows}) != 1:
            raise RuntimeError(f"Measured executable/library changed between {label} samples")
        timing_labels = set.intersection(*(set(row["timings_ms"]) for row in rows))
        variants[label] = {
            "samples": len(rows),
            "median_ms": {key: statistics.median(row["timings_ms"][key] for row in rows)
                          for key in sorted(timing_labels)},
            "median_instruction_scopes": {},
            "scripting_samples": [row["scripting"] for row in rows],
        }
        scopes = set.intersection(*(set(row["native"]["scopes"]) for row in rows))
        for scope in sorted(scopes):
            variants[label]["median_instruction_scopes"][scope] = statistics.median(
                row["native"]["scopes"][scope][0] for row in rows)
    key = "navigation_to_first_document_paint"
    before = variants["before"]["median_ms"][key]
    after = variants["after"]["median_ms"][key]
    return {"variants": variants,
            "first_document_frame_reduction_percent": (before - after) / before * 100
            if before else None,
            "first_document_frame_speedup": before / after if after else None}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before-binary", required=True, type=Path)
    parser.add_argument("--after-binary", required=True, type=Path)
    parser.add_argument("--before-arg", action="append", default=[],
                        help="Extra browser argument; use --before-arg=--flag")
    parser.add_argument("--after-arg", action="append", default=[],
                        help="Extra browser argument; use --after-arg=--flag")
    parser.add_argument("--cache-template", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--url", default="https://www.wikipedia.org/")
    parser.add_argument("--repeat", type=int, default=5)
    parser.add_argument("--width", type=int, default=1024)
    parser.add_argument("--height", type=int, default=768)
    parser.add_argument("--timeout", type=float, default=180)
    args = parser.parse_args()
    if args.repeat < 1:
        parser.error("--repeat must be positive")
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    args.before_binary = args.before_binary.resolve()
    args.after_binary = args.after_binary.resolve()
    args.cache_template = args.cache_template.resolve()
    results = []
    for index in range(1, args.repeat + 1):
        # Alternate the order between pairs to reduce order/temperature bias.
        labels = ("before", "after") if index % 2 else ("after", "before")
        for label in labels:
            results.append(run_sample(args, label, index,
                                      getattr(args, label + "_binary"),
                                      getattr(args, label + "_arg")))
    summary = {
        "url": args.url, "viewport": [args.width, args.height],
        "platform": platform.platform(),
        "endpoint": "native navigation to first submitted document frame; not web FCP",
        "cache_note": "fresh identical initial page/resource cache copies per sample; no raster snapshots; background network refresh remains enabled",
        "driver_sha256": sha256(Path(__file__)), **summarize(results),
        "results": results,
    }
    (args.output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({key: value for key, value in summary.items() if key != "results"},
                     indent=2))


if __name__ == "__main__":
    main()
