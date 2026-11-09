#!/usr/bin/env python3
"""Probe macOS instruction-counter capability; grants no performance credit.

Use tools/run_memory_bounded.py with a 60-second, 3-GiB bound. Only the current
Python process is observed. A tiny native helper also reports Metal device
availability. No browser, page, or rendering benchmark is run.
"""
from __future__ import annotations

import argparse
from dataclasses import asdict
import hashlib
import json
import os
from pathlib import Path
import platform
import signal
import subprocess
import sys
import time
import traceback

sys.path.insert(0, str(Path(__file__).resolve().parent))
from process_instruction_counts import MacCounters


def save(path, report):
    temporary = path.with_name(path.name + ".tmp")
    with temporary.open("x") as destination:
        json.dump(report, destination, indent=2, sort_keys=True)
        destination.write("\n")
    temporary.replace(path)


def cpu_work(seed):
    """A small fixed integer workload whose result is retained as evidence."""
    value = seed
    for index in range(100_000):
        value = (value * 1_664_525 + 1_013_904_223 + index) & 0xFFFFFFFF
    return value


def run_owned_command(command, timeout, evidence):
    """Retain evidence, terminate timed-out process groups, and reap roots."""
    evidence.update(command=command, timeout_seconds=timeout, timed_out=False,
                    cleanup_signals=[], stdout="", stderr="")
    started = time.monotonic()
    process = subprocess.Popen(command, text=True, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, start_new_session=True)
    evidence["pid"] = process.pid

    def signal_group(value):
        try:
            os.killpg(process.pid, value)
            sent = True
        except ProcessLookupError:
            sent = False
        evidence["cleanup_signals"].append({"signal": value.name, "sent": sent})

    def retain_partial(error):
        for name, value in (("stdout", error.stdout), ("stderr", error.stderr)):
            evidence[name] = value.decode(errors="replace") if isinstance(value, bytes) else value or ""

    try:
        try:
            stdout, stderr = process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired as error:
            evidence["timed_out"] = True
            retain_partial(error)
            # Do not reap the root between signals: compiler descendants may
            # ignore TERM or keep inherited output pipes open after it exits.
            signal_group(signal.SIGTERM)
            time.sleep(.25)
            signal_group(signal.SIGKILL)
            try:
                evidence["stdout"], evidence["stderr"] = process.communicate(timeout=2)
            except subprocess.TimeoutExpired as cleanup_error:
                retain_partial(cleanup_error)
                evidence["cleanup_error"] = str(cleanup_error)
                process.stdout.close()
                process.stderr.close()
                raise
            raise
        evidence.update(stdout=stdout, stderr=stderr)
        return subprocess.CompletedProcess(command, process.returncode, stdout, stderr)
    finally:
        if process.returncode is None:
            signal_group(signal.SIGKILL)
            process.wait(timeout=2)
        evidence.update(exit=process.returncode, root_reaped=process.returncode is not None,
                        elapsed_seconds=time.monotonic() - started)


def metal_probe(directory):
    """A device-availability observation, not a GPU or rendering benchmark."""
    result = {"status": "preparing", "capability_only": True, "available": None}
    try:
        if sys.platform != "darwin":
            raise RuntimeError("The Metal capability probe requires macOS")
        directory.mkdir(exist_ok=False)
        source = directory / "metal_probe.m"
        source.write_text('''#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <stdio.h>

int main(void) {
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        NSDictionary *result = @{
            @"available": [NSNumber numberWithBool:(device != nil)],
            @"name": device ? (id)[device name] : (id)[NSNull null]
        };
        NSData *data = [NSJSONSerialization dataWithJSONObject:result options:0 error:NULL];
        if (!data) return 2;
        fwrite([data bytes], 1, [data length], stdout);
        fputc('\\n', stdout);
        return 0;
    }
}
''')
        binary = directory / "metal_probe"
        result["source_sha256"] = hashlib.sha256(source.read_bytes()).hexdigest()
        command = ["xcrun", "--sdk", "macosx", "clang", "-fobjc-arc",
                   "-framework", "Foundation", "-framework", "Metal", str(source), "-o", str(binary)]
        result["compile"] = {}
        compiled = run_owned_command(command, 40, result["compile"])
        compiled.check_returncode()
        result["binary_sha256"] = hashlib.sha256(binary.read_bytes()).hexdigest()
        result["run"] = {}
        observed = run_owned_command([str(binary)], 5, result["run"])
        observed.check_returncode()
        value = json.loads(observed.stdout)
        if type(value.get("available")) is not bool or (value["available"]
                and (type(value.get("name")) is not str or not value["name"])):
            raise RuntimeError("Invalid native Metal capability response")
        result.update(status="available" if value["available"] else "unavailable", **value)
    except Exception as error:
        result.update(status="failed", error={"type": type(error).__name__,
                      "message": str(error), "traceback": traceback.format_exc()})
    return result


def probe(output):
    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    report = {
        "version": 1, "status": "running", "capability_only": True,
        "capability_available": False, "performance_credit": False,
        "scope": "Own-process instruction-counter capability plus Metal device availability; no browser or rendering measurement",
        "counter": "proc_pid_rusage/RUSAGE_INFO_V4/ri_instructions",
        "pid": os.getpid(), "started_unix": time.time(),
        "host": {"system": platform.system(), "release": platform.release(),
                 "version": platform.version(), "architecture": platform.machine(),
                 "logical_cpus": os.cpu_count(), "ram_bytes": None,
                 "runner_image_os": os.environ.get("ImageOS"),
                 "runner_image_version": os.environ.get("ImageVersion")},
        "observer_sha256": {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                            for path in [Path(__file__).resolve(),
                                         Path(__file__).resolve().with_name("process_instruction_counts.py")]},
        "workload": {"rounds": 3, "iterations_per_round": 100_000,
                     "description": "Fixed 32-bit integer recurrence; checksum retained"},
        "readings": [], "rounds": [], "errors": [],
    }
    # Never overwrite a previous observation, including a failed probe.
    with output.open("x") as destination:
        json.dump(report, destination, indent=2, sort_keys=True)
        destination.write("\n")

    def failure(stage, error):
        report["errors"].append({"stage": stage, "type": type(error).__name__,
                                 "message": str(error), "traceback": traceback.format_exc()})

    try:
        if sys.platform != "darwin":
            raise RuntimeError("This capability probe requires macOS")
        memory = subprocess.run(["sysctl", "-n", "hw.memsize"], text=True,
                                capture_output=True, timeout=5)
        report["host"]["ram_query"] = {"command": memory.args, "exit": memory.returncode,
                                        "stdout": memory.stdout, "stderr": memory.stderr}
        memory.check_returncode()
        ram = int(memory.stdout.strip())
        if ram <= 0:
            raise RuntimeError("macOS did not report positive physical RAM")
        report["host"]["ram_bytes"] = ram
    except Exception as error:
        failure("host_metadata", error)
    save(output, report)

    class RecordingMacCounters(MacCounters):
        def read(self, pid):
            reading = super().read(pid)
            # Record the constructor's own probe too. If MacCounters rejects
            # a zero instruction count, its actual zero sample remains here.
            report["readings"].append(asdict(reading))
            return reading

    try:
        api = RecordingMacCounters()
        for index in range(report["workload"]["rounds"]):
            before = api.read(report["pid"])
            checksum = cpu_work(0x9E3779B9 ^ index)
            after = api.read(report["pid"])
            delta = after.instructions - before.instructions
            row = {"round": index + 1, "before": asdict(before), "after": asdict(after),
                   "instruction_delta": delta, "checksum": f"{checksum:08x}",
                   "valid": False}
            report["rounds"].append(row)
            if (before.pid != report["pid"] or after.pid != report["pid"]
                    or before.identity != after.identity or before.exited or after.exited):
                raise RuntimeError("Counter identity changed or reported an exited current process")
            if before.instructions <= 0 or delta <= 0:
                raise RuntimeError("Own-process instructions were zero or did not increase")
            row["valid"] = True
            save(output, report)
        report["capability_available"] = True
    except Exception as error:
        failure("instruction_capability", error)

    # Run independently so unavailable counters still leave graphics evidence.
    # A missing Metal device does not change the instruction-capability result.
    report["metal_probe"] = {"status": "running", "capability_only": True, "available": None}
    save(output, report)
    report["metal_probe"] = metal_probe(output.parent / "metal-probe")

    passed = report["capability_available"] and not report["errors"]
    report.update(status="available" if passed else "unavailable_or_failed",
                  exit_code=0 if passed else 1, finished_unix=time.time(),
                  elapsed_seconds=time.monotonic() - started)
    save(output, report)
    print(json.dumps({"status": report["status"], "capability_only": True,
                      "capability_available": report["capability_available"],
                      "performance_credit": False, "report": str(output),
                      "architecture": report["host"]["architecture"],
                      "ram_bytes": report["host"]["ram_bytes"],
                      "metal": {key: report["metal_probe"].get(key)
                                for key in ("status", "available", "name", "error")},
                      "readings": report["readings"],
                      "instruction_deltas": [row["instruction_delta"] for row in report["rounds"]],
                      "errors": report["errors"]}), flush=True)
    return report["exit_code"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="New JSON evidence file")
    return probe(parser.parse_args().output)


if __name__ == "__main__":
    raise SystemExit(main())
