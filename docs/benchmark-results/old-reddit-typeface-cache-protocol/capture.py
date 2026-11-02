#!/usr/bin/env python3
"""One diagnostic native capture under the comparison's exact local policies.

Invoke under tools/run_memory_bounded.py. No reduction or cohort acceptance is
computed here. A rejected profile remains on disk and receives no count credit.
"""
import argparse
import json
import math
from pathlib import Path
import shutil
import subprocess
import sys
import traceback

import compare as protocol


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--counter-backend", choices=("callgrind", "cachegrind"), default="callgrind")
    parser.add_argument("--timeout", type=float, default=1800)
    args = parser.parse_args()
    args.binary, args.output = args.binary.resolve(), args.output.resolve()
    if not args.binary.is_file():
        parser.error("binary must exist")
    if not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error("timeout must be positive")
    try:
        args.output.relative_to(protocol.BUILD.resolve())
    except ValueError:
        parser.error("output must be below the repository's Build/ directory")
    if args.output.exists():
        parser.error("output already exists; evidence is never overwritten")
    args.output.mkdir(parents=True, mode=0o700)
    summary = {"status": "preparing", "valid": False, "diagnostic_only": True,
               "counter_backend": args.counter_backend,
               "instruction_metric": protocol.METRICS[args.counter_backend],
               "host_before": protocol.host_snapshot()}
    report_path = args.output / "summary.json"
    protocol.write_json(report_path, summary)
    try:
        with protocol.OfflineTransport() as transport:
            environment = protocol.clean_environment(transport.proxy)
            temporary = args.output / "tmp"
            temporary.mkdir(mode=0o700)
            environment.update(TMPDIR=str(temporary), XDG_CACHE_HOME=str(temporary / "xdg-cache"),
                               XDG_CONFIG_HOME=str(temporary / "xdg-config"), XDG_DATA_HOME=str(temporary / "xdg-data"))
            fixture = protocol.fixture_metadata()
            pin = protocol.pin_binary(args.binary, environment, [])
            fonts = protocol.pin_fonts(environment)
            inputs = {**protocol.binary_file_pins(pin), **fixture["file_sha256"],
                      **fonts["files_sha256"], **fonts["fontconfig_files_sha256"],
                      **protocol.pin_files(protocol.REPO / p for p in protocol.RUNTIME_ASSETS),
                      **protocol.pin_files([Path(__file__), Path(protocol.__file__),
                          protocol.WORK / "network_audit.py", protocol.DRIVER,
                          protocol.REPO / "tools/linux_instruction_counts.py",
                          protocol.REPO / "tools/process_instruction_counts.py",
                          protocol.AUDIT_CONFIG, protocol.EXPECTED_POSTS,
                          protocol.EXPECTED_NATIVE_DIAGNOSTICS, protocol.SUPPLEMENTARY_CONTROL])}
            prefix = args.output / "capture"
            command = ["xvfb-run", "-a", "-s", "-screen 0 1600x1200x24", sys.executable,
                       str(protocol.DRIVER), "--engine", "vox", "--counter-backend", args.counter_backend,
                       "--binary", str(args.binary), "--url", fixture["url"],
                       "--width", str(protocol.WIDTH), "--height", str(protocol.HEIGHT),
                       "--settle-seconds", "0", "--expect-title", protocol.TITLE,
                       "--capture-audit-config", str(protocol.AUDIT_CONFIG),
                       "--scratch-dir", str(temporary), "--output", str(prefix),
                       "--repeat", "1", "--timeout", str(args.timeout),
                       "--valgrind", str(Path(shutil.which("valgrind")).resolve())]
            for library in sorted(set(protocol.binary_file_pins(pin)) - {str(args.binary)}):
                command += ["--runtime-library", library]
            summary.update(status="running", command=command, environment=environment,
                           fixture=fixture, binary=pin, fonts=fonts, inputs_sha256=inputs,
                           network_policy={"proxy": transport.proxy, "forwarding": False,
                                           "mechanism": "exclusively bound non-listening loopback TCP port"})
            protocol.write_json(report_path, summary)
            protocol.write_json(args.output / "resource-network-inventory.json", fixture["network_inventory"])
            protocol.verify_files(inputs)
            with (args.output / "driver.log").open("w") as log:
                result = subprocess.run(command, cwd=protocol.REPO, env=environment,
                                        stdout=log, stderr=subprocess.STDOUT)
            summary.update(driver_exit=result.returncode, host_after=protocol.host_snapshot())
            protocol.verify_files(inputs)
            if result.returncode:
                raise RuntimeError("Driver rejected the diagnostic capture; preserve raw profile and failure report")
            capture = protocol.read_json(Path(str(prefix) + ".run-1.json"))
            if (capture.get("instruction_metric") != protocol.METRICS[args.counter_backend]
                    or capture.get("counter_backend") != args.counter_backend
                    or capture.get("exit") != 0 or capture.get("hardware_retired") is not False):
                raise ValueError("Unexpected counter identity or exit status")
            diagnostics = protocol.diagnostic_observation(capture["document_audit"], fixture)
            protocol.write_json(args.output / "native-diagnostics.json", diagnostics)
            content = protocol.validate_document(capture["document_audit"], fixture)
            protocol.write_json(args.output / "content-validation.json", content)
            summary.update(status="completed", valid=True, instructions=capture["instructions"],
                           capture_report=str(Path(str(prefix) + ".run-1.json")),
                           screenshot=capture["screenshot"],
                           native_renderer_diagnostic_count=diagnostics["raw_occurrences"],
                           raw_native_audit_sha256=diagnostics["raw_audit_sha256"])
            protocol.write_json(report_path, summary)
            print(json.dumps({key: summary[key] for key in ("valid", "diagnostic_only", "instruction_metric", "instructions")}))
            return 0
    except BaseException as error:
        summary.update(status="invalid", valid=False, error=f"{type(error).__name__}: {error}",
                       host_after=protocol.host_snapshot())
        protocol.write_json(report_path, summary)
        (args.output / "exception.txt").write_text(traceback.format_exc())
        print(json.dumps({"valid": False, "diagnostic_only": True, "error": summary["error"]}), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
