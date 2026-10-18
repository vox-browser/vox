#!/usr/bin/env python3
"""Sample native browser memory externally, separately from rendering benchmarks.

The first-frame reading follows observation of the native frame log marker;
neighboring samples retain its observation uncertainty. A delayed screenshot
keeps the process alive after pending image downloads finish. The steady window
ends one second before the saved-PNG marker, excluding normal capture overhead.
Kernel peak RSS and peak physical footprint cover the complete capture process.
"""

import argparse
import ctypes
import errno
import json
import os
from pathlib import Path
import re
import shutil
import statistics
import subprocess
import time

from measure_browser_instructions import VOX_CHROME_HEIGHT, crop_document_viewport, fresh_vox_cache, stop_process
from measure_browser_render import REPO, native_summary, scripting_summary, sha256
from process_instruction_counts import MacCounters, RusageInfoV4

FIRST_FRAME = "Ladybird V timing: document_install_to_first_paint "
SAVED_CAPTURE = "Saved Ladybird V window screenshot: "
INSTALLATION_EVENT = re.compile(
    r"^Ladybird V timing: (parse_document|document_install_to_first_paint) (\d+) ms$", re.MULTILINE)


def memory_reading(api, pid, launched_at):
    usage = RusageInfoV4()
    if api.lib.proc_pid_rusage(pid, 4, ctypes.byref(usage)) != 0:
        code = ctypes.get_errno()
        raise OSError(code, os.strerror(code), str(pid))
    return {"observed_seconds": time.monotonic() - launched_at,
            "resident_size_bytes": usage.ri_resident_size,
            "physical_footprint_bytes": usage.ri_phys_footprint,
            "lifetime_max_physical_footprint_bytes": usage.ri_lifetime_max_phys_footprint,
            "process_start_ticks": usage.ri_proc_start_abstime,
            "exited": usage.ri_proc_exit_abstime != 0}


def observe_installations(log, observed_seconds, events):
    matches = INSTALLATION_EVENT.findall(log)
    for phase, value in matches[len(events):]:
        events.append({"phase": phase, "native_elapsed_ms": int(value),
                       "observed_seconds": observed_seconds,
                       "installation": sum(row["phase"] == "parse_document" for row in events)
                       + (phase == "parse_document")})


def summarize_memory(readings, first_frame_index, saved_capture_seconds, peak_rss_bytes,
                     installation_events=()):
    if first_frame_index is None or first_frame_index < 1:
        raise RuntimeError("Missing first-frame memory observation or preceding sample")
    # Five seconds elapse after the browser's pending-resource barrier before
    # capture. Retain an earlier window to avoid PNG/bitmap allocation spikes.
    steady = [row for row in readings
              if saved_capture_seconds - 2 <= row["observed_seconds"] <= saved_capture_seconds - 1
              and not row["exited"] and row["physical_footprint_bytes"] > 0]
    if len(steady) < 5:
        raise RuntimeError("Insufficient pre-capture steady memory samples")
    first, preceding = readings[first_frame_index], readings[first_frame_index - 1]
    live = [row for row in readings if not row["exited"]]
    footprints = [row["physical_footprint_bytes"] for row in steady]
    median = statistics.median(footprints)
    installations = [event for event in installation_events if event["phase"] == "parse_document"]
    result = {
        "counter": "proc_pid_rusage/RUSAGE_INFO_V4",
        "first_frame_observation": first,
        "preceding_first_frame_observation": preceding,
        "first_frame_observation_gap_ms": (first["observed_seconds"] - preceding["observed_seconds"]) * 1000,
        "first_frame_note": "external observation after the native first-frame log marker; not an instruction-exact memory timestamp",
        "steady_window_seconds": [saved_capture_seconds - 2, saved_capture_seconds - 1],
        "steady_samples": len(steady),
        "steady_physical_footprint_bytes": median,
        "steady_resident_size_bytes": statistics.median(row["resident_size_bytes"] for row in steady),
        "steady_physical_footprint_range_bytes": [min(footprints), max(footprints)],
        "steady_physical_footprint_range_percent": (max(footprints) - min(footprints)) / median * 100 if median else None,
        "lifetime_peak_physical_footprint_bytes": max(
            max(row["lifetime_max_physical_footprint_bytes"], row["physical_footprint_bytes"])
            for row in readings),
        "observed_peak_resident_size_bytes": max(row["resident_size_bytes"] for row in live),
        "kernel_peak_rss_bytes": peak_rss_bytes,
        "peak_note": "root process lifetime through screenshot capture/exit; macOS wait4 ru_maxrss is bytes",
        "retention_scope": ("first frozen document" if len(installations) <= 1
                            else "navigation/session including later document replacement"),
        "installation_events": list(installation_events),
        "first_frame_observation_contains_replacement": any(
            event["installation"] > 1 and event["observed_seconds"] <= first["observed_seconds"]
            for event in installations),
    }
    if len(installations) > 1:
        replacement_at = installations[1]["observed_seconds"]
        pre_refresh = [row for row in live
                       if first["observed_seconds"] + .25 <= row["observed_seconds"] < replacement_at - .02]
        if len(pre_refresh) >= 5:
            result["pre_replacement_plateau"] = {
                "samples": len(pre_refresh),
                "window_seconds": [pre_refresh[0]["observed_seconds"], pre_refresh[-1]["observed_seconds"]],
                "physical_footprint_bytes": statistics.median(row["physical_footprint_bytes"] for row in pre_refresh),
                "resident_size_bytes": statistics.median(row["resident_size_bytes"] for row in pre_refresh),
                "note": "before observation of the second completed parse; parsing can already be underway",
            }
    return result


def run_memory_sample(args, label, index, binary, extra, api=None):
    api = api or MacCounters()
    prefix = args.output / f"{label}-{index}"
    window = Path(str(prefix) + ".window.png")
    screenshot = Path(str(prefix) + ".png")
    log_path = Path(str(prefix) + ".log")
    window.unlink(missing_ok=True)
    binary_hash = sha256(binary)
    library = binary.parent / "libLadybirdVSkiaText.dylib"
    if not library.is_file() and len(binary.parents) > 3:
        library = binary.parents[3] / library.name
    library_hash = sha256(library) if library.is_file() else None
    readings, installation_events, first_frame_index, saved_capture_seconds = [], [], None, None
    with fresh_vox_cache(args.cache_template, args.output) as (cache, digest):
        shutil.rmtree(cache / "snapshots", ignore_errors=True)
        env = dict(os.environ, LADYBIRD_CACHE_DIR=str(cache), LADYBIRD_DEBUG_TIMING="1",
                   VOX_PROFILE_INSTRUCTIONS="1", GC_MARKERS="1",
                   LADYBIRD_SCREENSHOT_DELAY_SECONDS=str(args.settle_seconds))
        env.pop("LADYBIRD_ENABLE_SNAPSHOT_CACHE", None)
        env.pop("GC_PRINT_STATS", None)
        if library.is_file():
            env["DYLD_LIBRARY_PATH"] = str(library.parent)
        command = [str(binary), *extra, "--window-width", str(args.width),
                   "--window-height", str(args.height + VOX_CHROME_HEIGHT),
                   "--screenshot", str(window), args.url]
        with log_path.open("w") as log:
            launched_at = time.monotonic()
            process = subprocess.Popen(command, cwd=REPO, env=env, stdout=log,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            text = ""
            peak_rss_bytes = None
            try:
                with log_path.open() as observer:
                    while True:
                        text += observer.read()
                        try:
                            reading = memory_reading(api, process.pid, launched_at)
                            readings.append(reading)
                            observe_installations(text, reading["observed_seconds"], installation_events)
                            if first_frame_index is None and FIRST_FRAME in text:
                                first_frame_index = len(readings) - 1
                            if saved_capture_seconds is None and SAVED_CAPTURE in text:
                                saved_capture_seconds = reading["observed_seconds"]
                        except OSError as error:
                            if error.errno not in (errno.ESRCH, errno.ENOENT):
                                raise
                        waited, status, usage = os.wait4(process.pid, os.WNOHANG)
                        if waited:
                            process.returncode = os.waitstatus_to_exitcode(status)
                            peak_rss_bytes = int(usage.ru_maxrss)
                            # The final marker may have arrived between the
                            # previous log read and the exact root exit sample.
                            text += observer.read()
                            if saved_capture_seconds is None and SAVED_CAPTURE in text:
                                saved_capture_seconds = time.monotonic() - launched_at
                            break
                        if time.monotonic() - launched_at > args.timeout:
                            raise RuntimeError("Memory capture exceeded its watchdog")
                        time.sleep(args.sample_interval)
            finally:
                stop_process(process)
        observe_installations(text, time.monotonic() - launched_at, installation_events)
        if process.returncode or not window.is_file():
            raise RuntimeError(f"Memory sample failed (exit {process.returncode}); see {log_path}")
        if saved_capture_seconds is None:
            raise RuntimeError("Missing saved capture marker")
        if sha256(binary) != binary_hash or (library_hash and sha256(library) != library_hash):
            raise RuntimeError("Measured executable or replay library changed")
        if len({row["process_start_ticks"] for row in readings}) != 1:
            raise RuntimeError("Process identity changed during memory capture")
        crop_document_viewport(window, screenshot, args.width, args.height)
        result = {"variant": label, "sample": index, "command": command,
                  "binary_sha256": binary_hash, "library_sha256": library_hash,
                  "cache_sha256": digest, "sample_interval_seconds": args.sample_interval,
                  "settle_seconds_after_pending_resource_barrier": args.settle_seconds,
                  "gc_environment": {key: env.get(key) for key in (
                      "GC_MARKERS", "GC_INITIAL_HEAP_SIZE", "GC_MAXIMUM_HEAP_SIZE",
                      "GC_FREE_SPACE_DIVISOR", "GC_DONT_GC", "GC_ENABLE_INCREMENTAL",
                      "GC_DISABLE_INCREMENTAL", "GC_NPROCS")},
                  "load_average": os.getloadavg(), "timings_ms": native_summary(text),
                  "scripting": scripting_summary(text),
                  "document_installations_before_capture": len(re.findall(
                      r"^Ladybird V timing: parse_document ", text, re.MULTILINE)),
                  "memory": summarize_memory(readings, first_frame_index, saved_capture_seconds,
                                             peak_rss_bytes, installation_events),
                  "readings": readings, "screenshot": str(screenshot),
                  "screenshot_sha256": sha256(screenshot), "log": str(log_path)}
    Path(str(prefix) + ".json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"variant": label, "sample": index, "memory": result["memory"]}), flush=True)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before-binary", required=True, type=Path)
    parser.add_argument("--after-binary", required=True, type=Path)
    parser.add_argument("--before-arg", action="append", default=[])
    parser.add_argument("--after-arg", action="append", default=[])
    parser.add_argument("--cache-template", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--url", default="https://www.wikipedia.org/")
    parser.add_argument("--repeat", type=int, default=5)
    parser.add_argument("--width", type=int, default=1024)
    parser.add_argument("--height", type=int, default=768)
    parser.add_argument("--sample-interval", type=float, default=.005)
    parser.add_argument("--settle-seconds", type=float, default=5)
    parser.add_argument("--timeout", type=float, default=180)
    args = parser.parse_args()
    if args.repeat < 1 or args.sample_interval <= 0 or args.settle_seconds < 5:
        parser.error("repeat/sample interval must be positive; settle delay must be at least five seconds")
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    args.cache_template = args.cache_template.resolve()
    args.before_binary = args.before_binary.resolve()
    args.after_binary = args.after_binary.resolve()
    results = []
    api = MacCounters()
    for index in range(1, args.repeat + 1):
        for label in (("before", "after") if index % 2 else ("after", "before")):
            results.append(run_memory_sample(args, label, index,
                           getattr(args, label + "_binary"), getattr(args, label + "_arg"), api))
    if len({row["cache_sha256"] for row in results}) != 1:
        raise RuntimeError("Initial cache bytes changed")
    summary = {"endpoint": "separate external memory cohort; native instruction/latency endpoint unchanged",
               "url": args.url, "viewport": [args.width, args.height], "results": results}
    (args.output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")


if __name__ == "__main__":
    main()
