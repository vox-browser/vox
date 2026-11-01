#!/usr/bin/env python3
"""Measure changed Cocoa layer publications during precise wheel input.

Run under tools/run_memory_bounded.py. This measures native publication, not
physical display scanout. The main-thread input timer is nominal: actual input
timestamps and cadence are reported, including late delivery during stalls.
mean_scroll_fps counts publications with a changed scroll position separately
from animation-only publications over the entire input window. The first
publication has no known prior position and supplies only the reference sample.
Retain raw evidence and run matched trials.
"""

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import statistics
import subprocess
import sys
import time

REPO = Path(__file__).resolve().parents[1]
ENDPOINT = "changed Cocoa layer contents after updateLayer; not physical scanout"


def distribution(values):
    if not values or any(not math.isfinite(v) or v < 0 for v in values):
        raise ValueError("Missing or invalid timing samples")
    ordered = sorted(values)
    return dict(n=len(values), mean=statistics.mean(values),
                median=statistics.median(values),
                p95=ordered[math.ceil(.95 * len(ordered)) - 1], max=ordered[-1])


def records(log, prefix):
    result = []
    for line in log.splitlines():
        if line.startswith(prefix + " "):
            parts = line.split()
            row = {key: float(value) for key, value in
                   (part.split("=", 1) for part in parts[2:])}
            if any(not math.isfinite(value) for value in row.values()):
                raise ValueError("Non-finite sample")
            result.append(dict(number=int(parts[1]), **row))
    if [row["number"] for row in result] != list(range(len(result))):
        raise ValueError(f"Missing, duplicated or unordered {prefix} records")
    return result


def intervals(rows):
    values = [b["t_us"] - a["t_us"] for a, b in zip(rows, rows[1:])]
    if not values or min(values) <= 0:
        raise ValueError("Insufficient samples or non-increasing timestamps")
    return values


def summarize(log, expected_inputs, target_hz=60, required_title=""):
    if "SCROLL_ERROR" in log:
        raise ValueError("Native probe reported an error")
    starts = [line for line in log.splitlines() if line.startswith("SCROLL_START ")]
    ends = [line for line in log.splitlines() if line.startswith("SCROLL_DONE ")]
    if len(starts) != 1 or len(ends) != 1 or "precise=1 " not in starts[0]:
        raise ValueError("Missing completion or precise input confirmation")
    # A long error message can itself scroll. Movement alone cannot establish
    # that the requested document loaded, so reject Vox's error-page title too.
    title = starts[0].partition(" title=")[2].strip()
    if title in {"Navigation error", "Navigation error — vox"}:
        raise ValueError("Navigation error page cannot supply scrolling acceptance")
    if required_title and required_title not in title:
        raise ValueError("Requested document title was not present when input started")
    inputs, frames = records(log, "SCROLL_INPUT"), records(log, "SCROLL_PUBLISH")
    counts = dict(re.findall(r"(inputs|publications)=(\d+)", ends[0]))
    if len(inputs) != expected_inputs or counts != {
            "inputs": str(expected_inputs), "publications": str(len(frames))}:
        raise ValueError("Input/publication counts do not match completion")
    if not frames or frames[-1]["inputs"] != expected_inputs:
        raise ValueError("Last input has no completed publication")
    if any(f["inputs"] < 1 or f["inputs"] > expected_inputs or
           f["inputs"] != int(f["inputs"]) for f in frames):
        raise ValueError("Publication has invalid input count")
    if any(b["inputs"] < a["inputs"] for a, b in zip(frames, frames[1:])):
        raise ValueError("Publication input counts moved backwards")
    intervals(frames)  # Validate tail publications too.
    if any(row["t_us"] < 0 for row in inputs + frames):
        raise ValueError("Negative timestamp")
    # Use the entire input window, with no best-frame selection or slow-frame
    # trimming. Exclude only publications after the last input timestamp.
    selected = [f for f in frames if inputs[0]["t_us"] <= f["t_us"] <= inputs[-1]["t_us"]]
    gaps = intervals(selected)
    input_gaps = intervals(inputs)
    if any(f["t_us"] < inputs[int(f["inputs"]) - 1]["t_us"] for f in frames):
        raise ValueError("Publication precedes its recorded input")
    window_us = inputs[-1]["t_us"] - inputs[0]["t_us"]
    positions = [f["scroll_y"] for f in selected]
    moving = sum(a != b for a, b in zip(positions, positions[1:]))
    if max(positions) - min(positions) < 1 or moving < 2:
        raise ValueError("Precise events did not scroll the document")
    scrolled = []
    for frame in selected:
        if not scrolled or frame["scroll_y"] != scrolled[-1]["scroll_y"]:
            scrolled.append(frame)
    scroll_gaps = intervals(scrolled)
    budget = 1_000_000 / target_hz
    return dict(protocol_version=2, endpoint=ENDPOINT, start=starts[0], completion=ends[0],
                completed_inputs=len(inputs), completed_publications=len(frames),
                measured_publications=len(selected), moving_intervals=moving,
                measurement_window_us=window_us,
                mean_publication_fps=len(selected) * 1_000_000 / window_us,
                mean_scroll_fps=moving * 1_000_000 / window_us,
                mean_publication_interval_fps=1_000_000 / statistics.mean(gaps),
                mean_scroll_interval_fps=1_000_000 / statistics.mean(scroll_gaps),
                first_publication_delay_us=selected[0]["t_us"] - inputs[0]["t_us"],
                last_publication_gap_us=inputs[-1]["t_us"] - selected[-1]["t_us"],
                first_counted_scroll_delay_us=scrolled[1]["t_us"] - inputs[0]["t_us"],
                last_scroll_publication_gap_us=inputs[-1]["t_us"] - scrolled[-1]["t_us"],
                input_delivery_hz=1_000_000 / statistics.mean(input_gaps),
                input_interval_us=distribution(input_gaps),
                publication_interval_us=distribution(gaps),
                scroll_interval_us=distribution(scroll_gaps),
                update_layer_us=distribution([f["frame_us"] for f in selected]),
                target_hz=target_hz, frame_budget_us=budget,
                intervals_over_budget=sum(gap > budget for gap in scroll_gaps),
                fraction_over_budget=sum(gap > budget for gap in scroll_gaps) / len(scroll_gaps),
                inputs=inputs, publications=frames)


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, default=REPO / "Build/v/Vox.app/Contents/MacOS/Vox")
    parser.add_argument("--url", default="https://pikabu.ru")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--cache-template", type=Path)
    parser.add_argument("--network-policy", required=True,
                        help="Describe live access or supplied network-blocking interposer; recorded verbatim")
    parser.add_argument("--insert-library", action="append", type=Path, default=[])
    parser.add_argument("--env", action="append", default=[])
    parser.add_argument("--width", type=int, default=1024)
    parser.add_argument("--height", type=int, default=764, help="Document viewport height, without chrome")
    parser.add_argument("--chrome-height", type=int, default=112,
                        help="Tab/toolbar, default bookmarks and status bar; use 84 for older bundles without bookmarks")
    parser.add_argument("--inputs", type=int, default=600)
    parser.add_argument("--input-hz", type=float, default=60)
    parser.add_argument("--target-hz", type=float, default=60)
    parser.add_argument("--delta", type=int, default=2)
    parser.add_argument("--reverse-every", type=int, default=60)
    parser.add_argument("--settle-seconds", type=float, default=12)
    parser.add_argument("--require-title", default="",
                        help="Wait for this case-sensitive window-title substring, then settle; reject a different start title")
    parser.add_argument("--script-policy", choices=("automatic", "enabled", "disabled"),
                        default="enabled", help="Use automatic to match ordinary browser navigation")
    parser.add_argument("--timeout", type=float, default=120)
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.error("This native publication probe requires macOS")
    if not (10 <= args.inputs <= 100000 and args.width > 0 and args.height > 0
            and 0 <= args.chrome_height <= 1000
            and 1 <= args.delta <= 100 and 1 <= args.reverse_every <= 100000
            and args.input_hz <= 1000 and args.settle_seconds <= 3600
            and all(math.isfinite(v) and v > 0 for v in
                    (args.input_hz, args.target_hz, args.timeout))
            and math.isfinite(args.settle_seconds) and args.settle_seconds >= 0):
        parser.error("Invalid dimensions, input schedule or timeout")
    if any("=" not in item for item in args.env):
        parser.error("--env expects NAME=VALUE")
    binary, output = args.binary.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    probe = output / "precise-scroll.dylib"
    source = REPO / "tools/measure_precise_scroll_darwin.m"
    source_digest = sha256(source)
    compile_command = ["clang", "-O2", "-Wall", "-Wextra", "-Werror",
                       "-dynamiclib", "-fobjc-arc", str(source),
                       "-framework", "Cocoa", "-framework", "QuartzCore",
                       "-Wl,-undefined,dynamic_lookup", "-o", str(probe)]
    with (output / "compile.log").open("w") as log:
        subprocess.run(compile_command, stdout=log, stderr=subprocess.STDOUT, check=True)
    if sha256(source) != source_digest:
        raise RuntimeError("Native probe source changed during compilation")
    cache = output / "cache"
    if args.cache_template:
        shutil.copytree(args.cache_template, cache)
    else:
        cache.mkdir()
    shutil.rmtree(cache / "snapshots", ignore_errors=True)
    # Saved bookmarks change the document viewport and saved proxy settings can
    # override the requested route. Never read or update the user's profile.
    profile = output / "profile"
    profile.mkdir()
    digest = hashlib.sha256()
    for path in sorted(cache.rglob("*")):
        if path.is_file():
            digest.update(str(path.relative_to(cache)).encode() + b"\0" + path.read_bytes())
    env = dict(os.environ)
    env.update(item.split("=", 1) for item in args.env)
    # Diagnostic workload changes are forbidden in this acceptance probe.
    for name in list(env):
        if name.startswith(("VOX_PROFILE_", "VOX_SCROLL_PROFILE_")) or name in {
                "VOX_DISABLE_SCROLL_RASTER_REUSE", "LADYBIRD_ENABLE_SNAPSHOT_CACHE",
                "LADYBIRD_SCREENSHOT_DELAY_SECONDS"}:
            env.pop(name)
    libraries = [path.resolve() for path in args.insert_library]
    # The signed bundle resolves its embedded bridges through @executable_path.
    # A global loader search override also changes transitive dependency lookup
    # and helper startup; exercise the bundle's ordinary loader configuration.
    env.pop("DYLD_LIBRARY_PATH", None)
    env.update(VOX_TEST_WINDOW="1", LADYBIRD_CACHE_DIR=str(cache),
               VOX_PROFILE_DIR=str(profile),
               DYLD_INSERT_LIBRARIES=":".join(map(str, [probe, *libraries])),
               VOX_PRECISE_INPUTS=str(args.inputs), VOX_PRECISE_REVERSE=str(args.reverse_every),
               VOX_PRECISE_HZ=str(args.input_hz), VOX_PRECISE_DELTA=str(args.delta),
               VOX_PRECISE_SETTLE=str(args.settle_seconds),
               VOX_PRECISE_FAILURE_CAPTURE=str(output / "navigation-error.png"),
               VOX_PRECISE_REQUIRED_TITLE=args.require_title)
    pinned = [binary, *sorted(binary.parent.glob("*.dylib")),
              Path(__file__).resolve(), source, probe, *libraries]
    # A private replay certificate changes the accepted network responses.
    # Retain its identity with the code, rather than just a mutable pathname.
    if env.get("SSL_CERT_FILE"):
        certificate = Path(env["SSL_CERT_FILE"]).resolve()
        if certificate.is_file():
            pinned.append(certificate)
    hashes = {str(path): sha256(path) for path in pinned}
    script_flags = {"automatic": [], "enabled": ["--enable-javascript"],
                    "disabled": ["--disable-javascript"]}[args.script_policy]
    command = [str(binary), *script_flags, "--window-width", str(args.width),
               "--window-height", str(args.height + args.chrome_height), args.url]
    evidence = dict(command=command, compile_command=compile_command,
                    source_and_binary_sha256=hashes, cache_sha256=digest.hexdigest(),
                    initial_profile="empty private profile; default bookmark bar; no saved proxy override",
                    chrome_height=args.chrome_height,
                    script_policy=args.script_policy,
                    viewport=[args.width, args.height], network_policy=args.network_policy,
                    schedule=dict(inputs=args.inputs, hz=args.input_hz, delta=args.delta,
                                  reverse_every=args.reverse_every, settle_seconds=args.settle_seconds,
                                  required_title=args.require_title,
                                  settle_basis="matching document title" if args.require_title else "process startup"),
                    environment={key: value for key, value in env.items() if key.startswith(
                        ("VOX_", "LADYBIRD_", "DYLD_")) or key in {
                            "HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY", "SSL_CERT_FILE"}})
    try:
        evidence["started_unix"] = time.time()
        evidence["host"] = dict(cpu_count=os.cpu_count(),
                                load_average_before=list(os.getloadavg()))
        with (output / "browser.log").open("w") as log:
            child = subprocess.Popen(command, cwd=REPO, env=env, stdout=log,
                                     stderr=subprocess.STDOUT)
            evidence["browser_pid"] = child.pid
            try:
                evidence["browser_exit_code"] = child.wait(timeout=args.timeout)
            except subprocess.TimeoutExpired:
                child.kill()
                evidence.update(browser_exit_code=child.wait(), browser_timed_out=True)
                raise RuntimeError(f"Browser timed out after {args.timeout} seconds")
        if evidence["browser_exit_code"]:
            raise RuntimeError(f"Browser exited {evidence['browser_exit_code']}")
        if hashes != {str(path): sha256(path) for path in pinned}:
            raise RuntimeError("Build or probe identity changed during measurement")
        summary = summarize((output / "browser.log").read_text(errors="replace"),
                            args.inputs, args.target_hz, args.require_title)
        (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
        evidence["valid"] = True
        print(json.dumps({key: value for key, value in summary.items()
                          if key not in {"inputs", "publications"}}, indent=2))
    except Exception as error:
        evidence.update(valid=False, error=str(error))
        raise
    finally:
        evidence["finished_unix"] = time.time()
        evidence["host"]["load_average_after"] = list(os.getloadavg())
        (output / "run.json").write_text(json.dumps(evidence, indent=2) + "\n")


if __name__ == "__main__":
    main()
