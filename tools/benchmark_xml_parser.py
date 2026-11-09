#!/usr/bin/env python3
"""Compare original, merged and working XML parsers through the real DOM.

Only the parser files are temporarily exchanged in the current checkout. All
three optimized C executables use the same DOM engine, harness, native libraries
and allocator. This is a parser component comparison, not a browser benchmark.
Run after the normal Linux native dependencies have been prepared. Source files
are restored on failures and ordinary termination; do not edit them concurrently.
"""
from __future__ import annotations

import argparse
import base64
from contextlib import contextmanager
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shlex
import shutil
import signal
import statistics
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = Path(__file__).resolve()
HARNESS = "tools/benchmark_xml_parser.v"
PARSER_FILES = ("html/dom_parser.v", "html/xml_parser.v", "xmlcompat/parser.v")
ORIGINAL = "9b3df2b374181102c9f621a11672d0ca5353cdca"
MERGED = "8e49769627b7c0713da221a2e83ffdf1e2c04c90"
FIXTURES = (
    ("menu-svg", "Tests/Browser/Brave/resources/techcrunch-menu.svg", 4000),
    ("star-svg", "Tests/Browser/Brave/resources/discord-star.svg", 1000),
    ("strokes-svg", "Tests/Browser/Brave/input/isolated-svg-strokes.svg", 20),
)
XML_INPUT_PREFIXES = (
    "xml/", "xmlcompat/", "dom/", "platform/", "svg/",
    "html/xml_", "html/vlib_xml", "html/dom_parser", "html/entities",
    "html/html_parser_fragment", "html/navigable", "xhr/document_response",
    "tools/benchmark_xml_parser", "tools/prepare_", "tools/prealloc_runtime/",
    "tools/build_linux_",
)
XML_INPUT_FILES = {
    ".github/workflows/linux-build.yml", "v.mod", "build-linux-browser.sh",
    "build-prod-browser.sh", "tools/test_linux_native.py", "tools/run_memory_bounded.py",
    *(path for _, path, _ in FIXTURES),
}


def xml_input_changed(path):
    return path in XML_INPUT_FILES or path.startswith(XML_INPUT_PREFIXES)


def digest(path):
    value = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def save(path, value):
    path = Path(path)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")
    temporary.replace(path)


def read(command):
    return subprocess.check_output(command, cwd=ROOT, text=True).strip()


def source_manifest():
    names = subprocess.check_output(
        ["git", "ls-files", "-z", "*.v", "*.c", "*.h", "*.cpp", "v.mod"], cwd=ROOT
    ).split(b"\0")
    paths = {os.fsdecode(name) for name in names if name}
    paths.add(HARNESS)
    return {name: digest(ROOT / name) for name in sorted(paths)
            if name not in PARSER_FILES and (ROOT / name).is_file()}


def native_manifest():
    roots = ("Build/linux/native", "Build/libregex/linux", "Build/deps")
    return {str(path.relative_to(ROOT)): digest(path)
            for root in roots for path in sorted((ROOT / root).rglob("*.a"))}


class ParserSources:
    """Restore only files still matching the bytes installed by this run."""

    def __init__(self, root=ROOT):
        self.root = root
        self.original = {}
        self.modes = {}
        for name in PARSER_FILES:
            path = root / name
            self.original[name] = path.read_bytes() if path.exists() else None
            self.modes[name] = path.stat().st_mode & 0o777 if path.exists() else 0o644
        self.installed = dict(self.original)

    def apply(self, files):
        for name, expected in self.installed.items():
            path = self.root / name
            actual = path.read_bytes() if path.exists() else None
            if actual != expected:
                raise RuntimeError(f"Concurrent edit to {name}; refusing to overwrite it")
        for name, data in files.items():
            if data == self.installed[name]:
                continue
            path = self.root / name
            if data is None:
                path.unlink()
            else:
                # A full disk or interrupted write must not truncate a source
                # file before the restoration guard has a chance to run.
                with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".xml-benchmark-",
                                                 delete=False) as stream:
                    temporary = Path(stream.name)
                    try:
                        stream.write(data)
                        stream.flush()
                        temporary.chmod(self.modes[name])
                        temporary.replace(path)
                    finally:
                        temporary.unlink(missing_ok=True)
            self.installed[name] = data

    def manifest(self):
        return {name: hashlib.sha256(data).hexdigest() if data is not None else None
                for name, data in self.installed.items()}

    @contextmanager
    def variant(self, files):
        try:
            self.apply(files)
            yield self.manifest()
        finally:
            self.apply(self.original)


def measure_child(arguments):
    """Collect the executable's kernel RSS high-water mark, outside its timers."""
    report, binary, *options = arguments
    started = time.monotonic_ns()
    process = subprocess.Popen([binary, *options], cwd=ROOT)
    _, status, usage = os.wait4(process.pid, 0)
    process.returncode = os.waitstatus_to_exitcode(status)
    save(report, {
        "exit_code": process.returncode,
        "process_elapsed_ns": time.monotonic_ns() - started,
        "process_cpu_ns": round((usage.ru_utime + usage.ru_stime) * 1e9),
        "peak_rss_bytes": int(usage.ru_maxrss) * 1024,
        "peak_rss_metric": "Linux wait4 ru_maxrss of the benchmark executable",
    })
    return process.returncode if process.returncode >= 0 else 128 - process.returncode


def ratio_summary(values):
    return {"pairs": values, "median": statistics.median(values), "worst": max(values),
            "best": min(values)}


def positive(value):
    number = float(value)
    if not math.isfinite(number) or number <= 0:
        raise argparse.ArgumentTypeError("expected a finite positive number")
    return number


class Comparison:
    def __init__(self, args):
        self.args = args
        self.output = args.output.resolve()
        self.output.mkdir(parents=True, exist_ok=False)
        self.state = {
            "schema_version": 1, "status": "in_progress",
            "scope": "Three parser variants against the same DOM engine; optimized C component benchmark",
            "started_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "head": read(["git", "rev-parse", "HEAD"]),
            "branch": read(["git", "branch", "--show-current"]),
            "working_status": read(["git", "status", "--short"]),
            "allocator": args.gc, "pairs": args.pairs,
            "commands": [], "builds": {}, "attempts": [], "comparisons": [], "failures": [],
            "thresholds": {"median_cpu_ratio": args.max_cpu_ratio,
                           "median_wall_ratio": args.max_wall_ratio,
                           "retained_used_ratio": args.max_memory_ratio,
                           "merged_ratio": args.max_merged_ratio},
            "performance_environment": {"VOX_ARENA_POISON": "0", "VOX_ARENA_NO_REUSE": "unset"},
        }
        self.persist()
        self.environment = dict(os.environ, V_C_ERROR_BUG_REPORT_DISABLED="1",
                                V_MACOS_V3_NO_FALLBACK="1")
        for name in ("GITHUB_TOKEN", "GH_TOKEN"):
            self.environment.pop(name, None)
        self.environment["PKG_CONFIG_PATH"] = str(ROOT / "Build/deps/lib/pkgconfig") + ":" + os.environ.get("PKG_CONFIG_PATH", "")
        self.runtime_environment = dict(self.environment, VOX_ARENA_POISON="0")
        self.runtime_environment.pop("VOX_ARENA_NO_REUSE", None)

    def persist(self):
        save(self.output / "comparison.json", self.state)

    def command(self, name, command, *, environment=None, limit=12, timeout=720):
        log = self.output / (name + ".log")
        report = self.output / (name + "-guard.json")
        invoked = [sys.executable, str(ROOT / "tools/run_memory_bounded.py"),
                   "--lock", str(self.output / (name + ".lock")), "--report", str(report),
                   "--limit-gib", str(limit), "--timeout", str(timeout), "--", *map(str, command)]
        record = {"name": name, "command": invoked, "log": str(log), "guard_report": str(report),
                  "started_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
        self.state["commands"].append(record)
        self.persist()
        print(f"{name}: {shlex.join(list(map(str, command)))}", flush=True)
        with log.open("x") as stream:
            process = subprocess.Popen(invoked, cwd=ROOT, env=environment or self.environment,
                                       stdout=stream, stderr=subprocess.STDOUT)
            try:
                code = process.wait()
            except BaseException:
                # SIGINT runs the supervisor's finally block, retiring its
                # compiler/test process group before parser files are restored.
                process.send_signal(signal.SIGINT)
                process.wait(timeout=30)
                raise
        record["exit_code"] = code
        if report.exists():
            record["guard"] = json.loads(report.read_text())
        self.persist()
        if code:
            print(log.read_text(errors="replace")[-12000:], file=sys.stderr)
        return code

    def require_command(self, name, command, **kwargs):
        if self.command(name, command, **kwargs):
            raise RuntimeError(f"{name} failed; full log retained")

    def ensure_commit(self, ref, stage="fetch"):
        if not re.fullmatch(r"[0-9a-f]{40}", ref):
            raise ValueError("References must be exact 40-character commit SHAs")
        exists = subprocess.run(["git", "cat-file", "-e", ref + "^{commit}"], cwd=ROOT,
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
        if not exists:
            fetch_environment = dict(self.environment)
            token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
            if token:
                # Checkout deliberately does not persist credentials. Supply a
                # read-only Actions token only to this fetch, never in command
                # arguments, repository config, receipts or benchmark children.
                index = int(fetch_environment.get("GIT_CONFIG_COUNT", "0"))
                fetch_environment["GIT_CONFIG_COUNT"] = str(index + 1)
                fetch_environment[f"GIT_CONFIG_KEY_{index}"] = "http.https://github.com/.extraheader"
                encoded = base64.b64encode(("x-access-token:" + token).encode()).decode()
                fetch_environment[f"GIT_CONFIG_VALUE_{index}"] = "AUTHORIZATION: basic " + encoded
            self.require_command(stage + "-" + ref[:12],
                                 ["git", "fetch", "--no-tags", "--depth", "1", "origin", ref],
                                 environment=fetch_environment, timeout=180)

    def historical_file(self, ref, name):
        self.ensure_commit(ref)
        return subprocess.check_output(["git", "show", f"{ref}:{name}"], cwd=ROOT)

    def selected(self):
        gate = {"run": True, "event": os.environ.get("GITHUB_EVENT_NAME", ""),
                "reason": "change filtering disabled"}
        self.state["change_selection"] = gate
        if not self.args.changed_only:
            return True
        if gate["event"] == "workflow_dispatch":
            gate["reason"] = "manual dispatch always runs"
        elif self.state["working_status"]:
            gate["reason"] = "working tree changed; run conservatively"
        else:
            try:
                event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
                if gate["event"] == "pull_request":
                    base = event["pull_request"]["base"]["sha"]
                    head = event["pull_request"]["head"]["sha"]
                elif gate["event"] == "push":
                    base, head = event["before"], event["after"]
                    if head != self.state["head"]:
                        raise ValueError("push head differs from the checked-out source")
                else:
                    raise ValueError("event has no supported complete base/head diff")
                if self.state["head"] != os.environ["GITHUB_SHA"]:
                    raise ValueError("checkout differs from the workflow event SHA")
                if base == "0" * 40 or head == "0" * 40:
                    raise ValueError("branch creation/deletion has no complete comparison")
                gate.update(base=base, head=head)
                for ref in (base, head):
                    self.ensure_commit(ref, stage="selection-fetch")
                command = ["git", "diff", "--no-ext-diff", "--no-textconv", "--name-only",
                           "--no-renames", "-z", base, head, "--"]
                paths = subprocess.check_output(command, cwd=ROOT, timeout=60).split(b"\0")
                # This compares complete trees, not a capped API file list or
                # HEAD^ from a shallow synthetic PR merge. Disabling renames
                # includes both sides of moved/deleted XML paths.
                changed = sorted({os.fsdecode(path) for path in paths if path})
                relevant = [path for path in changed if xml_input_changed(path)]
                gate.update(command=command, changed_files=changed, relevant_files=relevant,
                            run=bool(relevant), reason="relevant input changed" if relevant else "no XML benchmark inputs changed")
            except (OSError, ValueError, KeyError, TypeError, RuntimeError, subprocess.SubprocessError) as error:
                gate.update(run=True, reason="complete change set unavailable; run conservatively",
                            error=f"{type(error).__name__}: {error}")
        self.persist()
        print(json.dumps({"xml_performance_selection": {
            "run": gate["run"], "reason": gate["reason"],
            "changed_files": len(gate.get("changed_files", [])),
            "relevant_files": gate.get("relevant_files", []),
        }}), flush=True)
        return gate["run"]

    def prepare(self):
        compiler = str(Path(shutil.which(self.args.v) or self.args.v).resolve())
        cc = shutil.which(self.args.cc) or self.args.cc
        self.state["compiler"] = {"path": compiler, "sha256": digest(compiler),
                                  "version": read([compiler, "version"])}
        revision = subprocess.run(["git", "-C", str(Path(compiler).parent), "rev-parse", "HEAD"],
                                  text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        self.state["compiler"]["source_revision"] = revision.stdout.strip() if revision.returncode == 0 else None
        self.state["c_compiler"] = {"path": cc, "version": read([cc, "--version"])}
        self.state["host"] = {"uname": list(os.uname()), "cpu_count": os.cpu_count(),
                              "initial_load": list(os.getloadavg())}
        modules = []
        for name in ("http_compat", "linux_modules"):
            self.require_command("prepare-" + name,
                                 [sys.executable, str(ROOT / f"tools/prepare_{name}.py"), compiler])
            # The supervisor writes its own JSON to stderr after the one-line
            # preparation result. Identify the existing absolute module path.
            lines = (self.output / ("prepare-" + name + ".log")).read_text().splitlines()
            paths = [line for line in lines if line.startswith("/") and Path(line).is_dir()]
            if len(paths) != 1:
                raise RuntimeError(f"Could not identify {name} module directory")
            modules.append(paths[0])
        paths = [str(ROOT), modules[1], modules[0]]
        if self.args.gc == "prealloc":
            self.require_command("prepare-prealloc", [sys.executable,
                                 str(ROOT / "tools/prepare_prealloc_runtime.py"), compiler])
            lines = (self.output / "prepare-prealloc.log").read_text().splitlines()
            staged = [line for line in lines if line.startswith("/") and Path(line).is_dir()]
            if len(staged) != 1:
                raise RuntimeError("Could not identify prealloc runtime directory")
            paths.insert(1, staged[0])
            compiler = str(Path(staged[0]) / "compiler/v")
            self.state["prealloc_runtime_manifest"] = json.loads((Path(staged[0]) / "manifest.json").read_text())
        cflags = "-O2 -Werror=incompatible-pointer-types"
        if "clang" in self.state["c_compiler"]["version"].lower():
            cflags += " -Werror=incompatible-function-pointer-types -Wno-error=incompatible-pointer-types-discards-qualifiers"
        command = [compiler, "-b", "c", "-prod", "-showcc", "-memory-limit", "10G",
                   "-enable-globals", "-cc", cc, "-cstrict", "-cflags", cflags,
                   "-gc", "none" if self.args.gc == "prealloc" else "boehm", "-d", "use_openssl",
                   "-exclude", "@vlib/time/zoneinfo.native.v", "-path", "|".join([*paths, "@vmodules", "@vlib"])]
        command += ["-prealloc"] if self.args.gc == "prealloc" else ["-d", "dynamic_boehm"]
        self.state["effective_compiler"] = {"path": compiler, "sha256": digest(compiler)}
        self.state["preparation_sha256"] = {str(path.relative_to(ROOT)): digest(path)
                                           for path in (SCRIPT, ROOT / "tools/test_linux_native.py",
                                                        ROOT / "tools/prepare_http_compat.py",
                                                        ROOT / "tools/prepare_linux_modules.py",
                                                        ROOT / "tools/prepare_prealloc_runtime.py")}
        self.state["build_flags"] = command[1:]
        self.state["source_sha256"] = source_manifest()
        self.state["native_sha256"] = native_manifest()
        self.state["harness_sha256"] = digest(ROOT / HARNESS)
        self.state["fixtures"] = {name: {"path": path, "sha256": digest(ROOT / path)}
                                  for name, path, _ in FIXTURES}
        self.persist()
        return command

    def build(self):
        parser = ParserSources()
        if any(data is None for data in parser.original.values()):
            raise RuntimeError("Run from a working checkout containing all three current parser files")
        original = dict(parser.original)
        original["html/dom_parser.v"] = self.historical_file(self.args.baseline_ref, "html/dom_parser.v")
        original["html/xml_parser.v"] = None
        merged = dict(parser.original)
        for name in ("html/xml_parser.v", "xmlcompat/parser.v"):
            merged[name] = self.historical_file(self.args.merged_ref, name)
        self.state["historical_refs"] = {"original": self.args.baseline_ref, "merged": self.args.merged_ref}
        command = self.prepare()
        try:
            for label, files in (("original", original), ("merged", merged), ("candidate", parser.original)):
                binary = self.output / label
                with parser.variant(files) as manifest:
                    self.state["builds"][label] = {"parser_sha256": manifest, "binary": str(binary)}
                    self.persist()
                    self.require_command("build-" + label, [*command, "-o", str(binary), HARNESS],
                                         timeout=self.args.build_timeout)
                    if source_manifest() != self.state["source_sha256"]:
                        raise RuntimeError("Non-parser source changed during compilation")
                    self.state["builds"][label]["binary_sha256"] = digest(binary)
                    self.persist()
        finally:
            parser.apply(parser.original)
            self.state["parser_sources_restored"] = True
            self.persist()
        if native_manifest() != self.state["native_sha256"]:
            raise RuntimeError("Native library inputs changed between builds")

    def workloads(self):
        builtins = (("small-svg", 1, 2000), ("many-elements", 1000, 10),
                    ("attributes", 100, 20), ("mixed", 1000, 10),
                    ("indented", 1000, 10), ("entities", 1000, 10),
                    ("large-text", 16384, 3))
        for name, size, iterations in builtins:
            yield name, ["--workload", name, "--size", str(size), "--iterations", str(iterations)]
        for name, path, iterations in FIXTURES:
            yield name, ["--fixture", path, "--iterations", str(iterations)]

    def run_one(self, workload, options, pair, label):
        name = f"sample-{workload}-{pair:02d}-{label}"
        binary = self.state["builds"][label]
        if digest(binary["binary"]) != binary["binary_sha256"]:
            raise RuntimeError(f"{label} executable changed during measurement")
        high_water = self.output / (name + "-process.json")
        attempt = {"workload": workload, "pair": pair, "variant": label, "name": name}
        self.state["attempts"].append(attempt)
        self.persist()
        code = self.command(name, [sys.executable, str(SCRIPT), "measure-child", str(high_water),
                                 binary["binary"], *options, "--warmup", "3", "--mode", "cleanup"],
                            environment=self.runtime_environment, limit=3, timeout=self.args.run_timeout)
        attempt["exit_code"] = code
        if high_water.exists():
            attempt["process"] = json.loads(high_water.read_text())
        if code:
            self.state["failures"].append(f"{name}: process or memory guard failed")
            self.persist()
            return
        try:
            records = []
            for line in (self.output / (name + ".log")).read_text().splitlines():
                if line.startswith("{"):
                    value = json.loads(line)
                    if "parse_ns" in value:
                        records.append(value)
            if len(records) != 1:
                raise ValueError("expected exactly one benchmark JSON result")
            result = records[0]
            if result["allocator"] != self.args.gc or not result["process_cpu_available"]:
                raise ValueError("allocator mismatch or missing process CPU counter")
            if result["parse_ns"] <= 0 or result["parse_cpu_ns"] <= 0:
                raise ValueError("empty parse timing interval")
            memory_key = "arena_usage_available" if self.args.gc == "prealloc" else "gc_allocated_bytes_available"
            if not result[memory_key]:
                raise ValueError("allocation counter is unavailable")
            attempt["result"] = result
            save(self.output / (name + "-result.json"), result)
        except (KeyError, ValueError, TypeError) as error:
            attempt["result_error"] = str(error)
            self.state["failures"].append(f"{name}: {error}")
        self.persist()

    def compare(self, workload, control):
        attempts = [row for row in self.state["attempts"] if row["workload"] == workload]
        by_pair = {(row["pair"], row["variant"]): row for row in attempts}
        pairs = []
        identity = None
        for pair in range(1, self.args.pairs + 1):
            rows = [by_pair[(pair, label)] for label in (control, "candidate")]
            if any("result" not in row for row in rows):
                continue
            for row in rows:
                result = row["result"]
                current = {key: result[key] for key in ("source_sha256", "source_bytes", "tree",
                           "iterations", "warmup", "mode", "allocator")}
                if identity is None:
                    identity = current
                elif current != identity:
                    self.state["failures"].append(f"{workload}/{control}: fixture or full DOM identity changed")
                    return
                if workload in self.state["fixtures"] and result["source_sha256"] != self.state["fixtures"][workload]["sha256"]:
                    self.state["failures"].append(f"{workload}: fixture bytes differ from the pinned file")
                    return
            before, after = [row["result"] for row in rows]
            ratios = {"cpu": after["parse_cpu_ns"] / before["parse_cpu_ns"],
                      "wall": after["parse_ns"] / before["parse_ns"],
                      "batch_cpu": after["batch_cpu_ns"] / before["batch_cpu_ns"],
                      "batch_wall": after["batch_elapsed_ns"] / before["batch_elapsed_ns"],
                      "peak_rss": rows[1]["process"]["peak_rss_bytes"] / rows[0]["process"]["peak_rss_bytes"]}
            keys = ("arena_used_bytes_after_parse", "arena_capacity_bytes_after_parse") if self.args.gc == "prealloc" else ("gc_allocated_bytes_during_parse",)
            for key in keys:
                first, second = statistics.median(before[key]), statistics.median(after[key])
                if first <= 0:
                    self.state["failures"].append(f"{workload}/{control}: zero allocation baseline for {key}")
                    return
                ratios[key] = second / first
            pairs.append(ratios)
        if len(pairs) != self.args.pairs:
            self.state["failures"].append(f"{workload}/{control}: incomplete cohort ({len(pairs)}/{self.args.pairs})")
            return
        metrics = {key: ratio_summary([pair[key] for pair in pairs]) for key in pairs[0]}
        summary = {"workload": workload, "control": control, "identity": identity, "ratios": metrics}
        memory = "arena_used_bytes_after_parse" if self.args.gc == "prealloc" else "gc_allocated_bytes_during_parse"
        thresholds = {"cpu": self.args.max_cpu_ratio, "wall": self.args.max_wall_ratio,
                      memory: self.args.max_memory_ratio}
        if control == "merged":
            thresholds = {"cpu": self.args.max_merged_ratio, memory: self.args.max_merged_ratio}
        failures = [key for key, threshold in thresholds.items()
                    if threshold is not None and metrics[key]["median"] > threshold]
        summary["status"] = "regression" if failures else "passed"
        summary["failed_metrics"] = failures
        self.state["comparisons"].append(summary)
        if failures:
            self.state["failures"].append(f"{workload}/{control}: median ratio exceeded threshold for {', '.join(failures)}")
        print(json.dumps({"workload": workload, "control": control, "status": summary["status"],
                          "median_cpu_ratio": metrics["cpu"]["median"],
                          "worst_cpu_ratio": metrics["cpu"]["worst"],
                          "median_wall_ratio": metrics["wall"]["median"],
                          "median_memory_ratio": metrics[memory]["median"]}), flush=True)
        self.persist()

    def run(self):
        if not self.selected():
            self.state["status"] = "skipped"
            self.persist()
            return 0
        self.build()
        for workload, options in self.workloads():
            for pair in range(1, self.args.pairs + 1):
                order = ("original", "candidate", "merged") if pair % 2 else ("merged", "candidate", "original")
                for label in order:
                    self.run_one(workload, options, pair, label)
            for control in ("original", "merged"):
                self.compare(workload, control)
        if source_manifest() != self.state["source_sha256"]:
            self.state["failures"].append("Non-parser sources changed during measurement")
        self.state["host"]["final_load"] = list(os.getloadavg())
        self.state["status"] = "failed" if self.state["failures"] else "passed"
        self.persist()
        return int(bool(self.state["failures"]))


def interrupted(signum, _frame):
    raise InterruptedError(f"received signal {signum}")


def main():
    if sys.platform != "linux":
        raise SystemExit("This driver uses the repository's Linux native environment")
    if sys.argv[1:2] == ["measure-child"]:
        return measure_child(sys.argv[2:])
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--v", default=os.environ.get("V_BIN") or shutil.which("v") or str(Path.home() / "code/v/v"))
    parser.add_argument("--cc", default=os.environ.get("CC", "clang"))
    parser.add_argument("--gc", choices=("prealloc", "boehm"), default="prealloc")
    parser.add_argument("--baseline-ref", default=ORIGINAL)
    parser.add_argument("--merged-ref", default=MERGED)
    parser.add_argument("--output", type=Path, required=True, help="fresh evidence directory; never reused")
    parser.add_argument("--changed-only", action="store_true",
                        help="skip unrelated CI base/head changes; manual or uncertain events always run")
    parser.add_argument("--pairs", type=int, default=7)
    parser.add_argument("--max-cpu-ratio", type=positive, default=1.05)
    parser.add_argument("--max-wall-ratio", type=positive, help="optional noisy-host wall-time gate; always reported")
    parser.add_argument("--max-memory-ratio", type=positive, default=1.05)
    parser.add_argument("--max-merged-ratio", type=positive, default=1.05)
    parser.add_argument("--build-timeout", type=positive, default=720)
    parser.add_argument("--run-timeout", type=positive, default=90)
    args = parser.parse_args()
    if args.pairs < 7:
        parser.error("at least seven complete pairs are required")
    for name in (signal.SIGTERM, signal.SIGHUP):
        signal.signal(name, interrupted)
    comparison = Comparison(args)
    try:
        return comparison.run()
    except BaseException as error:
        comparison.state["status"] = "failed"
        comparison.state["failures"].append(f"{type(error).__name__}: {error}")
        comparison.persist()
        print(f"XML comparison failed: {error}; evidence: {comparison.output}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
