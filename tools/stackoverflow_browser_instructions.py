#!/usr/bin/env python3
"""Measure original-origin frozen Stack Overflow renders on Linux.

Run this orchestrator under tools/run_memory_bounded.py. Hardware perf and
Callgrind Ir are explicit, incompatible metrics. All observations and failures
are retained; the archive replay never forwards missing requests to the web.
"""
from __future__ import annotations

import argparse
import hashlib
from html.parser import HTMLParser
from fractions import Fraction
import json
import math
import os
from pathlib import Path
import re
import signal
import statistics
import subprocess
import sys
import time
from urllib.parse import urljoin, urlsplit

from page_archive import load_archive

REPO = Path(__file__).resolve().parents[1]
URL = "https://stackoverflow.com/questions"
WIDTH, HEIGHT = 1024, 768


def digest(path):
    value = hashlib.sha256()
    with Path(path).open("rb") as source:
        for part in iter(lambda: source.read(1024 * 1024), b""):
            value.update(part)
    return value.hexdigest()


def write_json(path, data):
    temporary = Path(str(path) + ".tmp")
    temporary.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    temporary.replace(path)


class FixtureHTML(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.ids, self.stylesheets, self.title_parts = [], [], []
        self.in_title, self.scripts, self.base = False, 0, URL

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "base" and attrs.get("href"):
            self.base = urljoin(self.base, attrs["href"])
        if attrs.get("id", "").startswith("question-summary-"):
            self.ids.append(attrs["id"])
        if tag == "script":
            self.scripts += 1
        if tag == "title":
            self.in_title = True
        if tag == "link" and "stylesheet" in attrs.get("rel", "").lower().split() and attrs.get("href"):
            self.stylesheets.append(urljoin(self.base, attrs["href"]))

    def handle_endtag(self, tag):
        if tag == "title":
            self.in_title = False

    def handle_data(self, value):
        if self.in_title:
            self.title_parts.append(value)


def local_only_font_sources(stylesheets):
    """Recognize literal local-only @font-face fallbacks in the sealed CSS.

    This deliberately narrow parser accepts simple literal names only. Unknown
    or URL-backed source syntax never grants a failed-font allowance.
    """
    families, blocked = {}, set()
    local = r'''local\(\s*(?:"([^"\\]*)"|'([^'\\]*)'|([^()"'\\]+?))\s*\)'''
    for stylesheet in stylesheets:
        stylesheet = re.sub(r"/\*.*?\*/", "", stylesheet, flags=re.S)
        for block in re.findall(r"@font-face\s*\{([^{}]*)\}", stylesheet, re.I | re.S):
            names = re.findall(r"(?:^|;)\s*font-family\s*:\s*([^;]+)", block, re.I)
            sources_decl = re.findall(r"(?:^|;)\s*src\s*:\s*([^;]+)", block, re.I)
            names = [value.strip().strip("\"'").casefold() for value in names]
            if len(names) != 1:
                blocked.update(names)
                continue
            name = names[0]
            if not name or "\\" in name or "," in name:
                continue
            if len(sources_decl) != 1:
                blocked.add(name)
                continue
            sources = list(re.finditer(local, sources_decl[0], re.I))
            remaining = re.sub(local, "LOCAL", sources_decl[0], flags=re.I).strip()
            if not sources or not re.fullmatch(r"LOCAL(?:\s*,\s*LOCAL)*", remaining):
                blocked.add(name)
                continue
            values = {next(group for group in match.groups() if group is not None).strip()
                      for match in sources}
            if not all(values):
                blocked.add(name)
                continue
            families.setdefault(name, set()).update(values)
    # The native audit exposes source strings without the local/url kind. If
    # any face in the family is ambiguous or URL-backed, allow no failures in
    # that family even when another face happens to use local() only.
    return {name: sorted(values) for name, values in sorted(families.items())
            if name not in blocked}


def fixture_metadata(archive):
    manifest = load_archive(archive)
    if manifest["url"] != URL or URL not in manifest["responses"]:
        raise ValueError("The archive must contain the original Stack Overflow questions URL")
    entry = manifest["responses"][URL]
    if entry["status"] != 200:
        raise ValueError("The archived document is not a successful response")
    parser = FixtureHTML()
    parser.feed((archive / "bodies" / entry["sha256"]).read_text(encoding="utf-8"))
    title = "".join(parser.title_parts).strip()
    if not parser.ids or len(parser.ids) != len(set(parser.ids)) or not title:
        raise ValueError("Archive lacks a title or distinct ordered question IDs")
    if parser.scripts:
        raise ValueError("This benchmark requires the script-free frozen guest DOM fixture")
    missing = sorted(set(parser.stylesheets) - manifest["responses"].keys())
    if missing:
        raise ValueError("Archive is missing required stylesheets: " + ", ".join(missing))
    for name, key in (("capture.json", "capture_report_sha256"), ("live.png", "live_png_sha256")):
        if key in manifest and digest(archive / name) != manifest[key]:
            raise ValueError(f"Archive provenance changed: {name}")
    stylesheets = [(archive / "bodies" / response["sha256"]).read_text(encoding="utf-8")
                   for response in manifest["responses"].values()
                   if any(header["name"].lower() == "content-type" and "text/css" in header["value"]
                          for header in response["headers"])]
    return {"archive": str(archive), "url": URL, "title": title,
            "manifest_sha256": digest(archive / "manifest.json"),
            "html_sha256": entry["sha256"], "html_bytes": entry["bytes"],
            "workload": manifest.get("workload", "Frozen guest DOM; scripts removed"),
            "source_document_request_method": manifest.get("source_document_request_method"),
            "replay_document_request_method": "GET", "question_ids": parser.ids,
            "required_stylesheets": sorted(set(parser.stylesheets)),
            "local_font_fallback_sources": local_only_font_sources(stylesheets),
            "archived_response_count": len(manifest["responses"]),
            "viewport": [WIDTH, HEIGHT]}


def pin_binary(binary):
    loaded = subprocess.run(["ldd", str(binary)], stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, check=True).stdout
    if "not found" in loaded:
        raise RuntimeError("Missing dynamic library for " + str(binary) + ":\n" + loaded)
    libraries = {}
    for line in loaded.splitlines():
        match = re.match(r"\s*(?:\S+\s+=>\s+)?(/\S+)\s+\(", line)
        if match:
            path = Path(match[1]).resolve()
            libraries[str(path)] = digest(path)
    if not libraries:
        raise RuntimeError("Could not establish the Linux browser's dynamic library identities")
    return {"path": str(binary), "sha256": digest(binary),
            "bytes": binary.stat().st_size, "dynamic_libraries_sha256": libraries,
            "ldd": loaded}


def verify_pins(pins):
    if digest(pins["path"]) != pins["sha256"]:
        raise RuntimeError("Pinned browser executable changed: " + pins["path"])
    for path, expected in pins["dynamic_libraries_sha256"].items():
        if digest(path) != expected:
            raise RuntimeError("Pinned runtime library changed: " + path)


def clean_environment(ready, use_display=False):
    # Deliberately construct and record the complete benchmark environment;
    # ambient proxies, GC modes, injection and application overrides cannot leak in.
    allowed = ("PATH", "HOME", "USER", "LOGNAME", "LANG", "LC_ALL", "TMPDIR",
               "LD_LIBRARY_PATH")
    result = {key: os.environ[key] for key in allowed if key in os.environ}
    if use_display:
        if not os.environ.get("DISPLAY"):
            raise ValueError("--use-display requires DISPLAY")
        for key in ("DISPLAY", "XAUTHORITY"):
            if key in os.environ:
                result[key] = os.environ[key]
    result.update(VOX_PROXY=ready["proxy"], SSL_CERT_FILE=ready["ca"], NO_PROXY="", no_proxy="",
                  GC_MARKERS="1", LIBGL_ALWAYS_SOFTWARE="1", LP_NUM_THREADS="1",
                  GALLIUM_DRIVER="llvmpipe", MESA_SHADER_CACHE_DISABLE="true",
                  LADYBIRD_ENABLE_SNAPSHOT_CACHE="0", VOX_COOKIE_FILE="")
    return result


def validate_document(audit, fixture):
    if (audit.get("url") != URL or audit.get("title") != fixture["title"]
            or audit.get("ready") != "complete" or not audit.get("fully_active")
            or (audit.get("viewport_width"), audit.get("viewport_height")) != (WIDTH, HEIGHT)):
        raise ValueError("Stack Overflow document identity/readiness/viewport gate failed")
    selections = {entry["name"]: entry for entry in audit.get("selections", [])}
    if not {"body", "questions", "images", "all"} <= selections.keys():
        raise ValueError("Native capture omitted a required content audit selection")
    questions = selections.get("questions", {})
    ids = [entry.get("attributes", {}).get("id") for entry in questions.get("elements", [])]
    if ids != fixture["question_ids"] or questions.get("count") != len(ids):
        raise ValueError("The captured document omitted, reordered, or replaced question summaries")
    bodies = selections.get("body", {}).get("elements", [])
    if selections["body"].get("count") != 1 or len(bodies) != 1 or len(bodies[0].get("text", "")) < 1000:
        raise ValueError("The captured document lacks the full body text")
    if selections["images"].get("count") != len(selections["images"].get("elements", [])):
        raise ValueError("The image audit was truncated")
    if selections["all"].get("count", 0) <= 0:
        raise ValueError("The DOM audit is empty")
    body_digest = hashlib.sha256(bodies[0]["text"].encode()).hexdigest()
    if bodies[0].get("text_sha256") != body_digest:
        raise ValueError("Native body text/hash disagree")
    if audit.get("font_set_present") and audit.get("fonts_status") != "loaded":
        raise ValueError("Document fonts are not settled")
    local_fallbacks = []
    for face in audit.get("font_faces", []):
        allowed_local = fixture.get("local_font_fallback_sources", {}).get(
            face.get("family", "").casefold(), [])
        sources = face.get("declared_sources", [])
        local_missing = (face.get("status") == "error" and bool(sources)
                         and all(source in allowed_local for source in sources))
        if local_missing:
            local_fallbacks.append({"family": face.get("family"), "declared_sources": sources,
                                    "style": face.get("style"), "weight": face.get("weight")})
        elif face.get("status") in ("loading", "error"):
            raise ValueError("A requested font did not load: " + str(face.get("family")))
        if face.get("status") == "loaded" and not face.get("parsed_font_present"):
            raise ValueError("A loaded custom font lacks its parsed font data")
    images, required_images = [], []
    for element in selections.get("images", {}).get("elements", []):
        rect = element.get("rect", {})
        x, y, width, height = (rect.get(key, 0) for key in ("x", "y", "width", "height"))
        if width <= 0 or height <= 0 or x >= WIDTH or y >= HEIGHT or x + width <= 0 or y + height <= 0:
            continue
        image = element.get("image") or {}
        decoded = ((image.get("complete") and image.get("natural_width", 0) > 0
                    and image.get("natural_height", 0) > 0)
                   or (image.get("paint_decoded") and image.get("paint_width", 0) > 0
                       and image.get("paint_height", 0) > 0))
        if not decoded:
            raise ValueError("A visible image is missing or undecoded: " + str(element.get("attributes")))
        source = image.get("current_src") or element.get("attributes", {}).get("src", "")
        source = urljoin(URL, source) if source else ""
        if urlsplit(source).scheme in ("http", "https"):
            required_images.append(source)
        images.append({"source": source, "rect": rect,
                       "natural_width": image.get("natural_width"),
                       "natural_height": image.get("natural_height"),
                       "paint_width": image.get("paint_width"), "paint_height": image.get("paint_height")})
    return {"question_ids": ids, "body_sha256": body_digest,
            "body_utf8_bytes": len(bodies[0]["text"].encode()),
            "visible_images": images, "required_images": sorted(set(required_images)),
            "fonts_status": audit.get("fonts_status"),
            "unavailable_local_font_fallbacks": local_fallbacks,
            "font_faces": [{key: face.get(key) for key in
                            ("family", "style", "weight", "status", "parsed_font_present",
                             "declared_sources")}
                           for face in audit.get("font_faces", [])]}


def classify_replay(rows, fixture, document):
    required = {URL, *fixture["required_stylesheets"], *document["required_images"]}
    served = {row["url"] for row in rows if row.get("archived") is True
              and 200 <= row.get("status", 0) < 300 and row.get("method") == "GET"}
    missing = sorted(required - served)
    result = {"request_count": len(rows), "missing_required_urls": missing,
              "unarchived": [row for row in rows if row.get("archived") is False],
              "transport_errors": [row for row in rows if "error" in row],
              "forwarding": False, "required_urls": sorted(required)}
    if missing:
        raise ValueError("Replay did not serve required document/CSS/visible images: " + ", ".join(missing))
    return result


def pair_statistics(pairs, required_reduction=.15):
    if not pairs or any(set(pair) != {"baseline", "candidate"} for pair in pairs):
        raise ValueError("Only complete baseline/candidate pairs may be summarized")
    metrics = {row["instruction_metric"] for pair in pairs for row in pair.values()}
    if len(metrics) != 1 or any(row["instructions"] <= 0 for pair in pairs for row in pair.values()):
        raise ValueError("Paired counts require one identical metric and positive values")
    before = [pair["baseline"]["instructions"] for pair in pairs]
    after = [pair["candidate"]["instructions"] for pair in pairs]
    differences = [baseline - candidate for baseline, candidate in zip(before, after)]
    reductions = [100 * (baseline - candidate) / baseline for baseline, candidate in zip(before, after)]
    baseline_median, candidate_median = statistics.median(before), statistics.median(after)
    return {"instruction_metric": metrics.pop(), "baseline_counts": before, "candidate_counts": after,
            "paired_differences": differences, "paired_reduction_percent": reductions,
            "baseline_median": baseline_median, "candidate_median": candidate_median,
            "median_reduction_percent": 100 * (baseline_median - candidate_median) / baseline_median,
            "median_paired_reduction_percent": statistics.median(reductions),
            "regressing_pairs": sum(value < 0 for value in differences),
            "worst_candidate_over_best_baseline": max(after) / min(before),
            "required_reduction_percent": required_reduction * 100,
            "target_met": Fraction(max(after), min(before)) <= 1 - Fraction(str(required_reduction))}


def run(args):
    args.output.mkdir(parents=True, exist_ok=False)
    summary_path = args.output / "summary.json"
    summary = {"status": "preparing", "valid": False, "counter_backend": args.counter_backend,
               "endpoint": "program exec through process exit after native document capture",
               "pairs_requested": args.pairs, "observations": [], "pairs": [],
               "required_reduction_percent": args.required_reduction * 100}
    replay = None
    replay_log = None
    try:
        fixture = fixture_metadata(args.archive)
        summary["fixture"] = fixture
        binaries = {"baseline": pin_binary(args.binary)}
        if args.candidate is not None:
            binaries["candidate"] = pin_binary(args.candidate)
            if binaries["baseline"]["dynamic_libraries_sha256"] != binaries["candidate"]["dynamic_libraries_sha256"]:
                raise ValueError("Baseline/candidate must use identical pinned dynamic libraries")
        summary["binaries"] = binaries
        summary["observer_sources_sha256"] = {name: digest(REPO / "tools" / name) for name in (
            "stackoverflow_browser_instructions.py", "measure_browser_instructions.py",
            "linux_instruction_counts.py", "process_instruction_counts.py", "page_archive.py")}
        config = args.output / "audit-config.json"
        write_json(config, {"selectors": [
            {"name": "body", "selector": "body", "limit": 1},
            {"name": "questions", "selector": '[id^="question-summary-"]', "limit": 1000, "attributes": ["id"]},
            {"name": "images", "selector": "img", "limit": 1000, "attributes": ["src", "srcset"]},
            {"name": "all", "selector": "*", "limit": 0}]})
        replay_directory = args.output / "replay"
        replay_log = (args.output / "replay-process.log").open("w")
        replay_command = [sys.executable, str(REPO / "tools/page_archive.py"), "replay",
                          str(args.archive), "--output", str(replay_directory)]
        replay = subprocess.Popen(replay_command, cwd=REPO, stdout=replay_log,
                                  stderr=subprocess.STDOUT, start_new_session=True)
        deadline = time.monotonic() + 30
        ready_file = replay_directory / "ready.json"
        while not ready_file.is_file():
            if replay.poll() is not None or time.monotonic() >= deadline:
                raise RuntimeError("Sealed replay did not start; see replay-process.log")
            time.sleep(.02)
        ready = json.loads(ready_file.read_text())
        if ready["manifest_sha256"] != fixture["manifest_sha256"] or ready.get("forwarding") is not False:
            raise ValueError("Replay identity does not match the verified sealed archive")
        environment = clean_environment(ready, args.use_display)
        summary.update(replay=ready, environment=environment, status="running")
        write_json(summary_path, summary)
        reference_png, reference_document = None, None
        requests = replay_directory / "requests.jsonl"
        for index in range(args.pairs):
            labels = (["baseline", "candidate"] if index % 2 == 0 else ["candidate", "baseline"]) if args.candidate else ["baseline"]
            pair = {}
            for label in labels:
                pins = binaries[label]
                verify_pins(pins)
                observation = args.output / f"pair-{index + 1:02d}-{label}"
                observation.mkdir()
                prefix = observation / "capture"
                command = [sys.executable, str(REPO / "tools/measure_browser_instructions.py"),
                           "--engine", "vox", "--counter-backend", args.counter_backend,
                           "--binary", pins["path"], "--url", URL, "--width", str(WIDTH),
                           "--height", str(HEIGHT), "--settle-seconds", "0", "--expect-title", fixture["title"],
                           "--capture-audit-config", str(config), "--output", str(prefix),
                           "--timeout", str(args.timeout), "--repeat", "1", "--valgrind", args.valgrind]
                for library in sorted(pins["dynamic_libraries_sha256"]):
                    command += ["--runtime-library", library]
                if reference_png is not None:
                    command += ["--expected-png", reference_png]
                if not args.use_display:
                    command = ["xvfb-run", "-a", "-s", "-screen 0 1280x1024x24", *command]
                row = {"pair": index + 1, "variant": label, "command": command,
                       "directory": str(observation), "status": "running"}
                summary["observations"].append(row)
                write_json(summary_path, summary)
                print(json.dumps({"status": "running", "pair": index + 1, "variant": label}), flush=True)
                offset = requests.stat().st_size if requests.exists() else 0
                with (observation / "driver.log").open("w") as log:
                    result = subprocess.run(command, cwd=REPO, env=environment, stdout=log, stderr=subprocess.STDOUT)
                row["driver_exit"] = result.returncode
                rows = [json.loads(line) for line in requests.read_bytes()[offset:].decode().splitlines()] if requests.exists() else []
                write_json(observation / "replay-requests.json", rows)
                if result.returncode:
                    row["status"] = "invalid"
                    raise RuntimeError(f"{label} pair {index + 1} capture failed; see {observation / 'driver.log'}")
                report = json.loads(Path(str(prefix) + ".run-1.json").read_text())
                document = validate_document(report["document_audit"], fixture)
                replay_result = classify_replay(rows, fixture, document)
                write_json(observation / "content-validation.json", document)
                write_json(observation / "replay-validation.json", replay_result)
                if reference_document is not None:
                    for key in ("question_ids", "body_sha256", "font_faces"):
                        if document[key] != reference_document[key]:
                            raise ValueError("Captured content differs from first baseline: " + key)
                else:
                    reference_png = report["screenshot"]
                    reference_document = document
                verify_pins(pins)
                row.update(status="valid", instructions=report["instructions"],
                           instruction_metric=report["instruction_metric"],
                           hardware_retired=report["hardware_retired"], screenshot=report["screenshot"],
                           document_validation=str(observation / "content-validation.json"),
                           replay_validation=str(observation / "replay-validation.json"))
                pair[label] = {"instructions": row["instructions"], "instruction_metric": row["instruction_metric"],
                               "directory": str(observation)}
                write_json(summary_path, summary)
                print(json.dumps({"status": "valid", "pair": index + 1, "variant": label,
                                  "instructions": row["instructions"], "instruction_metric": row["instruction_metric"]}), flush=True)
            summary["pairs"].append(pair)
            write_json(summary_path, summary)
        if fixture_metadata(args.archive) != fixture:
            raise RuntimeError("Fixture identity changed during the comparison")
        for name, expected in summary["observer_sources_sha256"].items():
            if digest(REPO / "tools" / name) != expected:
                raise RuntimeError("Measurement source changed during the comparison: " + name)
        summary.update(status="completed", valid=True)
        if args.candidate:
            summary["comparison"] = pair_statistics(summary["pairs"], args.required_reduction)
            summary["target_met"] = summary["comparison"]["target_met"]
        else:
            counts = [row["instructions"] for row in summary["observations"]]
            summary.update(instruction_metric=summary["observations"][0]["instruction_metric"],
                           baseline_counts=counts, baseline_median=statistics.median(counts), target_met=None)
        write_json(summary_path, summary)
        print(json.dumps({"summary": str(summary_path), "valid": True, "target_met": summary["target_met"]}), flush=True)
        return 0 if summary["target_met"] is not False else 1
    except Exception as error:
        for observation in summary["observations"]:
            if observation["status"] == "running":
                observation.update(status="invalid", error=str(error))
        summary.update(status="failed", valid=False, error=str(error))
        write_json(summary_path, summary)
        print(json.dumps({"summary": str(summary_path), "valid": False, "error": str(error)}), flush=True)
        return 1
    finally:
        if replay is not None and replay.poll() is None:
            os.killpg(replay.pid, signal.SIGTERM)
            try:
                replay.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(replay.pid, signal.SIGKILL)
                replay.wait()
        if replay_log is not None:
            replay_log.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, required=True, help="Baseline Linux Vox executable")
    parser.add_argument("--candidate", type=Path)
    parser.add_argument("--archive", type=Path, default=REPO / "Tests/Browser/Brave/sites/stackoverflow")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--pairs", "--repeat", type=int, default=3)
    parser.add_argument("--counter-backend", choices=["linux-perf", "callgrind", "cachegrind"], required=True)
    parser.add_argument("--valgrind", default="valgrind")
    parser.add_argument("--timeout", type=float, default=1800)
    parser.add_argument("--required-reduction", type=float, default=.15)
    parser.add_argument("--use-display", action="store_true", help="Use the explicitly supplied DISPLAY instead of a fresh Xvfb")
    args = parser.parse_args()
    if args.pairs < 1 or not math.isfinite(args.timeout) or args.timeout <= 0 or not 0 <= args.required_reduction < 1:
        parser.error("Invalid pairs, timeout, or required reduction")
    if sys.platform != "linux":
        parser.error("This measurement driver requires Linux")
    for name in ("binary", "candidate", "archive", "output"):
        value = getattr(args, name)
        if value is not None:
            setattr(args, name, value.resolve())
    if args.output.exists():
        parser.error("The output directory already exists; preserve it and choose a new directory")
    raise SystemExit(run(args))


if __name__ == "__main__":
    main()
