#!/usr/bin/env python3
"""Matched old.reddit.com software-instruction captures via the unchanged driver.

Run this observer under tools/run_memory_bounded.py. It writes only below Build/,
keeps every attempted observation, and stops at the first invalid observation.
The metric is software guest instruction references, not hardware-retired
instructions or native latency. The endpoint includes startup, native capture,
audit work and process teardown; external Xvfb work is outside the counter.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
from html.parser import HTMLParser
import json
import math
import os
from pathlib import Path
import platform
import re
import shutil
import socket
import statistics
import subprocess
import sys
import time
import traceback
from urllib.parse import unquote, urljoin, urlsplit

REPO = Path(__file__).resolve().parents[2]
BUILD = REPO / "Build"
WORK = BUILD / "reddit-optimization"
SHARED_LIBRARY_DIR = BUILD / "linux"
FIXTURE = REPO / "pixel_tests/sites/old-reddit-worldnews"
HTML = FIXTURE / "index.html"
AUDIT_CONFIG = WORK / "audit-config.json"
EXPECTED_POSTS = WORK / "expected-posts.json"
EXPECTED_NATIVE_DIAGNOSTICS = WORK / "expected-native-diagnostics.json"
SUPPLEMENTARY_CONTROL = WORK / "supplementary-control.json"
WIDTH, HEIGHT = 1280, 900
TITLE = "World News"
METRICS = {name: name + "_guest_instruction_references" for name in ("callgrind", "cachegrind")}
DRIVER = REPO / "tools/measure_browser_instructions.py"
RUNTIME_ASSETS = [
    "aria/aria_roles.json", "dom/resources/pdfjs/viewer.html",
    "optimizedsites/assets/wikipedia.ico", "optimizedsites/assets/reddit.png",
    "optimizedsites/assets/vlang.png", "optimizedsites/assets/hacker-news.ico",
    "url/public_suffix_list_reversed.dat",
    "layout/resources/chromium/broken-image-200.png",
    "layout/resources/chromium/broken-image-100.png", "html/media_controls.css",
    "adblock/extended/procedural.js", "adblock/engine.snapshot.bin",
    "adblock/engine.snapshot.json.gz", "adblock/engine.js.gz",
    "browserjs/vendor/es-module-lexer-1.7.0/lexer.asm.js", "browserhistory/history.css",
    "css/ua_default.css", "css/ua_quirks_mode.css", "css/ua_mathml_default.css",
    "css/ua_svg_default.css",
]


def digest(path):
    with Path(path).open("rb") as source:
        result = hashlib.file_digest(source, "sha256")
    return result.hexdigest()


def object_digest(value):
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"),
                         ensure_ascii=False, allow_nan=False).encode()
    return hashlib.sha256(encoded).hexdigest()


def read_json(path):
    def reject_constant(value):
        raise ValueError("Non-finite JSON value: " + value)
    return json.loads(Path(path).read_text(), parse_constant=reject_constant)


def write_json(path, value):
    # Atomic progress updates preserve the latest complete evidence on interruption.
    path = Path(path)
    path.resolve().relative_to(BUILD.resolve())
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False,
                                    allow_nan=False) + "\n")
    temporary.replace(path)


def pin_files(paths):
    result = {}
    for path in sorted({Path(p).resolve() for p in paths}):
        if not path.is_file():
            raise ValueError("Missing pinned input: " + str(path))
        result[str(path)] = digest(path)
    return result


def verify_files(pins):
    for name, expected in pins.items():
        if digest(name) != expected:
            raise ValueError("Pinned input changed: " + name)


def native_diagnostic_contract():
    contract = read_json(EXPECTED_NATIVE_DIAGNOSTICS)
    if (contract.get("schema_version") != 2
            or contract.get("source_channel") != "javascript_diagnostics"
            or contract.get("classified_as") != "native_renderer_diagnostics"
            or contract.get("known_diagnostic") != "Shadow replay: Empty shadow bounds"
            or contract.get("expected_canonical_diagnostics") != ["Shadow replay: Empty shadow bounds"]
            or contract.get("minimum_occurrences") != 1
            or contract.get("expected_native_reported_error_count") != 0
            or contract.get("expected_native_reported_errors") != []):
        raise ValueError("Source-specific native-renderer diagnostic contract changed")
    return contract


def diagnostic_observation(audit, fixture):
    contract = fixture["native_diagnostic_contract"]
    messages = audit.get("javascript_diagnostics")
    if (not isinstance(messages, list) or not messages
            or any(message != contract["known_diagnostic"] for message in messages)):
        raise ValueError("Require a positive list containing only the exact known native shadow "
                         "diagnostic; absent, empty, changed, unclassified/JavaScript messages fail")
    return {"source_channel": "javascript_diagnostics", "raw_messages": list(messages),
            "raw_occurrences": len(messages), "raw_audit_sha256": object_digest(audit),
            "canonical_classification": contract["expected_canonical_diagnostics"],
            "comparison_policy": "Only repeated occurrences of this exact native message are canonicalized; raw evidence is retained"}


class FixtureHTML(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.posts, self.images, self.stylesheets, self.title = [], [], [], []
        self.scripts = 0
        self.in_title = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "script":
            self.scripts += 1
        if tag == "title":
            self.in_title = True
        if "thing" in attrs.get("class", "").split() and attrs.get("data-fullname", "").startswith("t3_"):
            self.posts.append(attrs["data-fullname"])
        if tag == "img":
            self.images.append(attrs.get("src", ""))
        if tag == "link" and "stylesheet" in attrs.get("rel", "").split():
            self.stylesheets.append(attrs.get("href", ""))

    def handle_endtag(self, tag):
        if tag == "title":
            self.in_title = False

    def handle_data(self, data):
        if self.in_title:
            self.title.append(data)


def fixture_metadata():
    parser = FixtureHTML()
    parser.feed(HTML.read_text())
    expected = read_json(EXPECTED_POSTS)
    if (not isinstance(expected, list) or len(expected) != 30 or len(set(expected)) != 30
            or parser.posts != expected or "".join(parser.title).strip() != TITLE
            or parser.scripts):
        raise ValueError("Frozen fixture title, script policy or 30 ordered post IDs changed")
    config = read_json(AUDIT_CONFIG)
    selectors = {row["name"]: row for row in config.get("selectors", [])}
    for name, selector, count in (("posts", '.thing[data-fullname^="t3_"]', 30),
                                   ("body", "body", 1), ("images", "img", len(parser.images))):
        row = selectors.get(name, {})
        if row.get("selector") != selector or row.get("limit", 0) < count:
            raise ValueError("Capture audit selector is absent or truncated: " + name)
    if "data-fullname" not in selectors["posts"].get("attributes", []):
        raise ValueError("Post audit must include data-fullname")
    if "src" not in selectors["images"].get("attributes", []):
        raise ValueError("Image audit must include src")
    if config.get("describe_paint_geometry") is not True:
        raise ValueError("Paint geometry auditing must remain enabled")
    for reference in parser.images + parser.stylesheets:
        resolved = urlsplit(urljoin(HTML.resolve().as_uri(), reference))
        if resolved.scheme != "file" or resolved.netloc not in ("", "localhost"):
            raise ValueError("Fixture has a nonlocal required resource: " + reference)
        local = Path(unquote(resolved.path)).resolve()
        local.relative_to(FIXTURE.resolve())
        if not local.is_file():
            raise ValueError("Fixture resource is missing: " + reference)
    files = pin_files(p for p in FIXTURE.rglob("*") if p.is_file())
    font_face_count = sum(len(re.findall(r"@font-face\b", p.read_text(), re.I))
                          for p in FIXTURE.rglob("*.css"))
    inventory_script = WORK / "network_audit.py"
    spec = importlib.util.spec_from_file_location("vox_reddit_network_audit", inventory_script)
    inventory_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(inventory_module)
    inventory = inventory_module.build_inventory()
    if inventory["valid_for_frozen_offline_capture"] is not True:
        raise ValueError("Fixture network inventory has external/ambiguous automatic resources")
    return {"url": HTML.resolve().as_uri(), "title": TITLE, "viewport": [WIDTH, HEIGHT],
            "workload": "Frozen 2024-01-01 old.reddit.com/r/worldnews fixture; scripts removed",
            "posts": expected, "image_sources": parser.images,
            "stylesheets": parser.stylesheets, "declared_font_face_count": font_face_count,
            "file_sha256": files, "file_manifest_sha256": object_digest(files),
            "audit_config_sha256": digest(AUDIT_CONFIG),
            "expected_posts_sha256": digest(EXPECTED_POSTS), "network_inventory": inventory,
            "native_diagnostic_contract": native_diagnostic_contract(),
            "native_diagnostic_contract_sha256": digest(EXPECTED_NATIVE_DIAGNOSTICS)}


class OfflineTransport:
    """Reserve an unreachable local HTTP proxy for this observer's lifetime.

    The TCP socket is bound exclusively but never listens or forwards. Thus a
    proxy connection fails immediately on loopback, with no origin DNS lookup or
    remote connection. Normal file/data resources retain their existing paths.
    Both the native browsernet and requestserver/libcurl adapters honor VOX_PROXY.
    This is a transport policy, not a system-wide network sandbox.
    """
    def __init__(self):
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            self.socket.bind(("127.0.0.1", 0))
        except BaseException:
            self.socket.close()
            raise
        self.proxy = "http://127.0.0.1:" + str(self.socket.getsockname()[1])

    def close(self):
        self.socket.close()

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()


def clean_environment(offline_proxy=None):
    # Preserve ordinary account identity without importing ambient browser, proxy,
    # collector, tracing, preload or JSC overrides. Per-observation directories
    # below Build/ supply temporary files, profiles and XDG caches.
    allowed = ("PATH", "HOME", "USER", "LOGNAME", "LANG", "LC_ALL")
    result = {key: os.environ[key] for key in allowed if key in os.environ}
    result.update(GC_MARKERS="1", LIBGL_ALWAYS_SOFTWARE="1", LP_NUM_THREADS="1",
                  GALLIUM_DRIVER="llvmpipe", MESA_SHADER_CACHE_DISABLE="true",
                  LADYBIRD_ENABLE_SNAPSHOT_CACHE="0", VOX_COOKIE_FILE="",
                  LADYBIRD_SCREENSHOT_SCALE="1", PYTHONDONTWRITEBYTECODE="1",
                  LD_LIBRARY_PATH=str(SHARED_LIBRARY_DIR),
                  NO_PROXY="", no_proxy="", TZ="UTC")
    if offline_proxy is not None:
        if not re.fullmatch(r"http://127\.0\.0\.1:[1-9][0-9]*", offline_proxy):
            raise ValueError("Offline proxy must be the observer's reserved loopback endpoint")
        result.update({name: offline_proxy for name in
                       ("VOX_PROXY", "HTTP_PROXY", "http_proxy", "HTTPS_PROXY", "https_proxy",
                        "ALL_PROXY", "all_proxy")})
    return result


def ldd_libraries(binary, environment):
    result = subprocess.run(["ldd", str(binary)], env=environment, check=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if "not found" in result.stdout:
        raise ValueError("Missing dynamic dependency for " + str(binary) + ":\n" + result.stdout)
    entries = {}
    for line in result.stdout.splitlines():
        match = re.match(r"\s*(\S+)\s+=>\s+(/\S+)\s+\(", line)
        if match:
            name, path = match.groups()
        else:
            match = re.match(r"\s*(/\S+)\s+\(", line)
            if not match:
                continue
            path = match[1]
            name = Path(path).name
        resolved = Path(path).resolve()
        entries[name] = {"path": str(resolved), "sha256": digest(resolved)}
    if not entries:
        raise ValueError("No runtime library identities found for " + str(binary))
    return entries, result.stdout


def pin_binary(binary, environment, additional_libraries):
    libraries, listing = ldd_libraries(binary, environment)
    extras = set(additional_libraries)
    # Split-C binaries live in baseline-c/candidate-c, while their linker runpath
    # and this controlled LD_LIBRARY_PATH select the one shared codec directory.
    # dlopen("libVoxJPEGXL.so") does not appear in the executable's ldd output.
    shared_jpegxl = SHARED_LIBRARY_DIR / "libVoxJPEGXL.so"
    if not shared_jpegxl.is_file():
        raise ValueError("Shared Linux JPEG XL runtime is missing: " + str(shared_jpegxl))
    extras.add(shared_jpegxl)
    jpegxl = binary.parent / "libVoxJPEGXL.so"
    if jpegxl.is_file():
        extras.add(jpegxl)
    # Mesa loads its software rasterizer dynamically; it is absent from the
    # browser's direct ldd output. Record both it and its linked dependencies.
    for directory in (Path("/usr/lib"), Path("/lib")):
        for pattern in ("*/dri/swrast_dri.so", "*/dri/libdril_dri.so"):
            extras.update(directory.glob(pattern))
    dynamic = {}
    for library in sorted({p.resolve() for p in extras}):
        dependencies, _ = ldd_libraries(library, environment)
        content_hash = digest(library)
        if library.name in dynamic:
            previous = dynamic[library.name]
            if previous["sha256"] != content_hash or previous["dependencies"] != dependencies:
                raise ValueError("Ambiguous runtime library identity: " + library.name)
            previous.setdefault("equivalent_paths", []).append(str(library))
            continue
        dynamic[library.name] = {"path": str(library), "sha256": content_hash,
                                 "dependencies": dependencies}
    return {"path": str(binary), "sha256": digest(binary), "bytes": binary.stat().st_size,
            "libraries": libraries, "dynamically_loaded_libraries": dynamic, "ldd": listing}


def library_content_identity(pin):
    return {"linked": {key: row["sha256"] for key, row in pin["libraries"].items()},
            "dynamic": {key: {"sha256": row["sha256"],
                              "dependencies": {name: value["sha256"] for name, value in row["dependencies"].items()}}
                        for key, row in pin["dynamically_loaded_libraries"].items()}}


def binary_file_pins(pin):
    result = {pin["path"]: pin["sha256"]}
    result.update({row["path"]: row["sha256"] for row in pin["libraries"].values()})
    for row in pin["dynamically_loaded_libraries"].values():
        result[row["path"]] = row["sha256"]
        result.update({path: row["sha256"] for path in row.get("equivalent_paths", [])})
        result.update({item["path"]: item["sha256"] for item in row["dependencies"].values()})
    return result


def pin_fonts(environment):
    listing = subprocess.run(["fc-list", "--format=%{file}\n"], env=environment,
                             check=True, stdout=subprocess.PIPE, text=True).stdout
    paths = {Path(row) for row in listing.splitlines() if row}
    if not paths:
        raise ValueError("Fontconfig returned no available fonts")
    fonts = pin_files(paths)
    configs = pin_files(path for path in Path("/etc/fonts").rglob("*") if path.is_file())
    return {"files_sha256": fonts, "fontconfig_files_sha256": configs,
            "manifest_sha256": object_digest({"fonts": fonts, "configuration": configs})}


def host_snapshot():
    return {"unix_time": time.time(), "cpu_count": os.cpu_count(),
            "load_average": list(os.getloadavg()), "platform": platform.platform()}


def text_identity(element):
    text = element.get("text")
    if not isinstance(text, str):
        raise ValueError("Capture omitted an element's full text")
    raw = text.encode()
    actual = hashlib.sha256(raw).hexdigest()
    if element.get("text_sha256") != actual or element.get("text_utf8_bytes") != len(raw):
        raise ValueError("Native text, byte count and hash disagree")
    return {"text": text, "text_sha256": actual, "text_utf8_bytes": len(raw)}


def validated_rect(element):
    rect = element.get("rect")
    if not isinstance(rect, dict) or not {"x", "y", "width", "height"} <= rect.keys():
        raise ValueError("Element lacks complete geometry")
    for value in rect.values():
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
            raise ValueError("Element geometry contains a nonfinite or nonnumeric value")
    return rect


def validate_document(audit, fixture):
    if (audit.get("url") != fixture["url"] or audit.get("title") != TITLE
            or audit.get("ready") != "complete" or audit.get("fully_active") is not True
            or [audit.get("viewport_width"), audit.get("viewport_height")] != [WIDTH, HEIGHT]
            or audit.get("paint_commands", 0) <= 0):
        raise ValueError("Document identity/readiness/viewport/paint gate failed")
    rows = audit.get("selections", [])
    selections = {row["name"]: row for row in rows}
    if len(selections) != len(rows) or not {"body", "posts", "images"} <= selections.keys():
        raise ValueError("Audit selections are missing or ambiguous")
    for name in ("body", "posts", "images"):
        if selections[name].get("count") != len(selections[name].get("elements", [])):
            raise ValueError("Audit selection was truncated: " + name)
    bodies = selections["body"]["elements"]
    posts = selections["posts"]["elements"]
    images = selections["images"]["elements"]
    if len(bodies) != 1:
        raise ValueError("Capture must contain exactly one body")
    body = text_identity(bodies[0])
    if body["text_utf8_bytes"] < 1000:
        raise ValueError("Captured body text is incomplete")
    ids = [row.get("attributes", {}).get("data-fullname") for row in posts]
    if ids != fixture["posts"] or len(ids) != 30:
        raise ValueError("Capture omitted, reordered or replaced the 30 expected posts")
    sources = [row.get("attributes", {}).get("src", "") for row in images]
    if sources != fixture["image_sources"]:
        raise ValueError("Capture omitted, reordered or replaced fixture images")
    post_content = [dict(id=ids[index], **text_identity(row)) for index, row in enumerate(posts)]
    image_content, unresolved = [], []
    geometry = {"body": validated_rect(bodies[0]),
                "posts": [validated_rect(row) for row in posts],
                "images": []}
    for index, row in enumerate(images):
        rect = validated_rect(row)
        geometry["images"].append(rect)
        state = row.get("image")
        if not isinstance(state, dict):
            raise ValueError("An image has no retained image-state audit")
        x, y, width, height = (rect[key] for key in ("x", "y", "width", "height"))
        visible = width > 0 and height > 0 and x < WIDTH and y < HEIGHT and x + width > 0 and y + height > 0
        decoded = ((state.get("complete") is True and state.get("natural_width", 0) > 0
                    and state.get("natural_height", 0) > 0)
                   or (state.get("paint_decoded") is True and state.get("paint_width", 0) > 0
                       and state.get("paint_height", 0) > 0))
        if visible and not decoded:
            raise ValueError("Visible image is incomplete or undecoded: " + sources[index])
        identity = {"index": index, "attributes": row.get("attributes", {}),
                    "image": state, "visible": visible, "decoded": decoded}
        image_content.append(identity)
        if not decoded:
            unresolved.append({**identity, "rect": rect,
                               "reason": "outside viewport or zero-area; retained and compared exactly"})
    if audit.get("font_set_present") and audit.get("fonts_status") != "loaded":
        raise ValueError("Document font set has not settled")
    faces = audit.get("font_faces", [])
    if not isinstance(faces, list):
        raise ValueError("Font-face audit is missing")
    if not audit.get("font_set_present") and fixture["declared_font_face_count"]:
        raise ValueError("Declared author fonts have no font-set audit")
    for face in faces:
        if face.get("status") in ("loading", "error"):
            raise ValueError("Requested font did not load: " + str(face.get("family")))
        if face.get("status") == "loaded" and face.get("parsed_font_present") is not True:
            raise ValueError("Loaded font lacks parsed data")
    if audit.get("native_reported_error_count", 0) or audit.get("native_reported_errors"):
        raise ValueError("Native document reported script/runtime errors")
    observed_diagnostics = diagnostic_observation(audit, fixture)
    diagnostics = observed_diagnostics["canonical_classification"]
    paint = audit.get("paint_geometry")
    if not isinstance(paint, list):
        raise ValueError("Paint geometry audit is missing")
    return {"body": body, "posts": post_content, "images": image_content,
            "unresolved_nonvisible_images": unresolved,
            "fonts": {"font_set_present": audit.get("font_set_present"),
                      "fonts_status": audit.get("fonts_status"), "faces": faces},
            "geometry": geometry, "paint_geometry": paint,
            "paint_commands": audit["paint_commands"],
            "diagnostics": {"source_channel": "javascript_diagnostics",
                            "classified_native_renderer": diagnostics,
                            "unclassified_or_javascript": [],
                            "native_reported_error_count": 0, "native_reported_errors": []},
            # Every other raw audit field remains exact. Raw diagnostic lists,
            # counts and audit hashes are retained separately per observation.
            "native_document_audit_canonical_diagnostics": {
                **audit, "javascript_diagnostics": diagnostics}}


def load_reference_capture(path, fixture):
    """Validate the immutable first diagnostic's pixels and complete audit.

    Its original observer rejection remains unchanged. Its Callgrind count is
    diagnostic only and never enters the prospective comparison cohort.
    """
    contract = fixture["native_diagnostic_contract"]
    reference = contract["reference_capture"]
    if path != Path(reference["report"]).resolve():
        raise ValueError("Reference report must be the pinned first diagnostic capture")
    png = Path(reference["screenshot"]).resolve()
    expected_pins = {
        str(path): reference["report_sha256"],
        str(png): reference["screenshot_file_sha256"],
        reference["original_failure_summary"]: reference["original_failure_summary_sha256"],
        reference["original_failure_exception"]: reference["original_failure_exception_sha256"],
        str(EXPECTED_NATIVE_DIAGNOSTICS): fixture["native_diagnostic_contract_sha256"],
    }
    for name in expected_pins:
        Path(name).resolve().relative_to(BUILD.resolve())
    verify_files(expected_pins)
    original = read_json(reference["original_failure_summary"])
    if (original.get("status") != "invalid" or original.get("valid") is not False
            or original.get("driver_exit") != 0
            or original.get("error") != reference["original_error"]):
        raise ValueError("Original observer failure provenance changed")
    report = read_json(path)
    if (report.get("exit") != 0 or report.get("root_final_exit_sample") is not True
            or report.get("binary_sha256") != reference["baseline_binary_sha256"]
            or report.get("measurement_driver_sha256") != digest(DRIVER)
            or report.get("capture_audit_config_sha256") != fixture["audit_config_sha256"]
            or report.get("url") != fixture["url"] or report.get("settle_seconds") != 0
            or Path(report["screenshot"]).resolve() != png
            or report.get("screenshot_sha256") != reference["screenshot_file_sha256"]
            or original["fixture"]["file_sha256"] != fixture["file_sha256"]
            or object_digest(report["document_audit"]) != reference["audit_sha256"]):
        raise ValueError("Reference report identity, inputs or completion changed")
    document = validate_document(report["document_audit"], fixture)
    from PIL import Image
    with Image.open(png) as raw:
        raw.load()
        rgba = raw.convert("RGBA")
    rgba_sha256 = hashlib.sha256(rgba.tobytes()).hexdigest()
    pixels = report.get("screenshot_validation", {})
    if (rgba.size != (WIDTH, HEIGHT)
            or (pixels.get("width"), pixels.get("height")) != (WIDTH, HEIGHT)
            or rgba_sha256 != reference["decoded_rgba_sha256"]
            or pixels.get("decoded_rgba_sha256") != rgba_sha256):
        raise ValueError("Reference PNG does not decode to the pinned first diagnostic pixels")
    return {"document": document, "png": png, "file_pins": expected_pins,
            "metadata": {"report": str(path), "report_sha256": reference["report_sha256"],
                         "audit_sha256": reference["audit_sha256"],
                         "content_sha256": object_digest(document),
                         "screenshot": str(png), "screenshot_file_sha256": digest(png),
                         "decoded_rgba_sha256": rgba_sha256,
                         "baseline_binary_sha256": reference["baseline_binary_sha256"],
                         "raw_native_renderer_diagnostic_count": len(report["document_audit"]["javascript_diagnostics"]),
                         "original_observer_status": "invalid",
                         "original_observer_error": original["error"],
                         "source_counter_backend": report["counter_backend"],
                         "instructions_used_in_acceptance_statistics": False}}


def load_supplementary_control(fixture, reference):
    """Revalidate the pinned raw baseline from the still-invalid first cohort.

    This control can only tighten the separate final conservative gate. It is
    never added to the new cohort's pairs, medians or required observation count.
    """
    control = read_json(SUPPLEMENTARY_CONTROL)
    if (control.get("schema_version") != 1 or control.get("instructions") != 6842705460
            or control.get("counter_backend") != "cachegrind"
            or control.get("instruction_metric") != METRICS["cachegrind"]
            or digest(SUPPLEMENTARY_CONTROL) != fixture["native_diagnostic_contract"]["multiplicity_evidence"]["supplementary_control_sha256"]):
        raise ValueError("Pinned supplementary Cachegrind control contract changed")
    pins = {**control["evidence_sha256"], **control["measurement_source_sha256"],
            **control["valgrind_runtime_sha256"],
            control["baseline_binary"]: control["baseline_binary_sha256"],
            str(SUPPLEMENTARY_CONTROL): digest(SUPPLEMENTARY_CONTROL)}
    verify_files(pins)
    original = read_json(control["cohort_summary"])
    observation = read_json(control["observation_result"])
    report = read_json(control["report"])
    if (original.get("status") != "invalid" or original.get("valid") is not False
            or original.get("error") != control["original_error"]
            or len(original.get("observations", [])) != 1
            or original["observations"][0].get("variant") != "baseline"
            or original.get("pairs") != []
            or observation.get("status") != "invalid" or observation.get("driver_exit") != 0
            or observation.get("error") != control["original_error"]
            or report.get("exit") != 0 or report.get("root_final_exit_sample") is not True
            or report.get("missing_final_sample_count") != 0
            or report.get("counter_backend") != "cachegrind"
            or report.get("instruction_metric") != METRICS["cachegrind"]
            or report.get("hardware_retired") is not False
            or report.get("binary_sha256") != reference["metadata"]["baseline_binary_sha256"]
            or report.get("binary_sha256") != control["baseline_binary_sha256"]
            or report.get("measurement_driver_sha256") != digest(DRIVER)
            or report.get("counter_module_sha256") != digest(REPO / "tools/process_instruction_counts.py")
            or report.get("linux_counter_module_sha256") != digest(REPO / "tools/linux_instruction_counts.py")
            or report.get("capture_audit_config_sha256") != fixture["audit_config_sha256"]
            or report.get("url") != fixture["url"] or report.get("settle_seconds") != 0
            or original["fixture"]["file_sha256"] != fixture["file_sha256"]
            or object_digest(report["document_audit"]) != control["raw_audit_sha256"]
            or report.get("cachegrind_output") != control["profile"]
            or Path(control["profile"]).name != "capture.run-1.cachegrind." + str(report["pid"])):
        raise ValueError("Supplementary control provenance, input or successful process-exit evidence changed")
    counter_path = REPO / "tools/linux_instruction_counts.py"
    spec = importlib.util.spec_from_file_location("vox_reddit_strict_counter", counter_path)
    counter = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(counter)
    instructions = counter.parse_cachegrind(control["profile"])
    if instructions != control["instructions"] or instructions != report.get("instructions"):
        raise ValueError("Strictly reparsed supplementary control count changed")
    document = validate_document(report["document_audit"], fixture)
    if document != reference["document"]:
        raise ValueError("Supplementary control differs from the fixed reference beyond known diagnostic multiplicity")
    diagnostics = diagnostic_observation(report["document_audit"], fixture)
    if diagnostics["raw_occurrences"] != control["raw_native_renderer_diagnostic_count"]:
        raise ValueError("Supplementary control raw diagnostic evidence changed")
    from PIL import Image
    with Image.open(control["screenshot"]) as raw:
        raw.load()
        rgba = raw.convert("RGBA")
    rgba_sha256 = hashlib.sha256(rgba.tobytes()).hexdigest()
    pixels = report.get("screenshot_validation", {})
    if (rgba.size != (WIDTH, HEIGHT) or report.get("screenshot") != control["screenshot"]
            or digest(control["screenshot"]) != report.get("screenshot_sha256")
            or rgba_sha256 != reference["metadata"]["decoded_rgba_sha256"]
            or rgba_sha256 != control["decoded_rgba_sha256"]
            or pixels.get("decoded_rgba_sha256") != rgba_sha256 or pixels.get("exact") is not True):
        raise ValueError("Supplementary control pixels differ from the original fixed reference")
    return {"instructions": instructions, "file_pins": pins,
            "fonts": original["fonts"], "runtime_assets_sha256": original["runtime_assets_sha256"],
            "library_identity": library_content_identity(original["binaries"]["baseline"]),
            "valgrind": report["valgrind"],
            "metadata": {"report": control["report"], "profile": control["profile"],
                         "instructions": instructions, "counter_backend": "cachegrind",
                         "instruction_metric": METRICS["cachegrind"],
                         "strict_parser": str(counter_path), "strict_reparse_passed": True,
                         "original_cohort_status": "invalid", "candidate_observations": 0,
                         "raw_native_renderer_diagnostic_count": diagnostics["raw_occurrences"],
                         "raw_audit_sha256": diagnostics["raw_audit_sha256"],
                         "canonical_content_sha256": object_digest(document),
                         "decoded_rgba_sha256": rgba_sha256,
                         "included_in_normal_pairs_or_medians": False,
                         "included_in_mandatory_supplementary_gate": True}}


def first_differences(before, after, prefix="", limit=32):
    differences = []
    def visit(left, right, path):
        if len(differences) >= limit or left == right:
            return
        if isinstance(left, dict) and isinstance(right, dict):
            for key in sorted(left.keys() | right.keys()):
                if key not in left or key not in right:
                    differences.append({"path": path + "/" + key, "before": left.get(key), "after": right.get(key)})
                else:
                    visit(left[key], right[key], path + "/" + key)
                if len(differences) >= limit:
                    return
        elif isinstance(left, list) and isinstance(right, list):
            if len(left) != len(right):
                differences.append({"path": path + "/length", "before": len(left), "after": len(right)})
            for index, (a, b) in enumerate(zip(left, right)):
                visit(a, b, path + "/" + str(index))
                if len(differences) >= limit:
                    return
        else:
            differences.append({"path": path, "before": left, "after": right})
    visit(before, after, prefix)
    return differences


def compare_document(reference, actual, observation):
    changed = [key for key in reference if reference[key] != actual[key]]
    result = {"exact": not changed, "changed_sections": changed,
              "baseline_sha256": object_digest(reference), "actual_sha256": object_digest(actual),
              "first_differences": first_differences(reference, actual)}
    write_json(observation / "document-comparison.json", result)
    if changed:
        raise ValueError("Native content or geometry differs: " + ", ".join(changed)
                         + "; see document-comparison.json (no tolerance applied)")


def statistics_for_pairs(pairs):
    before = [pair["baseline"]["instructions"] for pair in pairs]
    after = [pair["candidate"]["instructions"] for pair in pairs]
    if not before or any(type(value) is not int or value <= 0 for value in before + after):
        raise ValueError("A cohort requires complete positive instruction counts")
    baseline_median, candidate_median = statistics.median(before), statistics.median(after)
    reductions = [100 * (a - b) / a for a, b in zip(before, after)]
    return {"baseline_counts": before, "candidate_counts": after,
            "baseline_median": baseline_median, "candidate_median": candidate_median,
            "paired_instruction_savings": [a - b for a, b in zip(before, after)],
            "paired_reduction_percent": reductions,
            "median_reduction_percent": 100 * (baseline_median - candidate_median) / baseline_median,
            "median_paired_reduction_percent": statistics.median(reductions),
            "worst_candidate_over_best_baseline": max(after) / min(before),
            "conservative_reduction_percent": 100 * (1 - max(after) / min(before)),
            "conservative_gate": {"expression": "10 * max(candidate) <= 9 * min(baseline)",
                                  "left_integer": 10 * max(after), "right_integer": 9 * min(before)},
            "target_met": 10 * max(after) <= 9 * min(before),
            "regressing_pairs": sum(b > a for a, b in zip(before, after))}


def supplementary_gate(statistics, control):
    baseline_counts = statistics["baseline_counts"] + [control["instructions"]]
    candidate_counts = statistics["candidate_counts"]
    best_baseline, worst_candidate = min(baseline_counts), max(candidate_counts)
    left, right = 10 * worst_candidate, 9 * best_baseline
    return {"expression": "10 * max(final_candidates) <= 9 * min(final_baselines + supplementary_controls)",
            "final_baseline_counts": statistics["baseline_counts"],
            "supplementary_control_counts": [control["instructions"]],
            "lowest_control": best_baseline, "highest_candidate": worst_candidate,
            "left_integer": left, "right_integer": right,
            "conservative_reduction_percent": 100 * (1 - worst_candidate / best_baseline),
            "target_met": left <= right}


def run(args):
    args.output.mkdir(parents=True, exist_ok=False, mode=0o700)
    summary_path = args.output / "summary.json"
    metric = METRICS[args.counter_backend]
    summary = {"status": "preparing", "valid": False, "target_met": False,
               "counter_backend": args.counter_backend, "instruction_metric": metric,
               "hardware_retired": False, "pairs_requested": args.pairs,
               "endpoint": "program exec through process exit after native document PNG capture and audit",
               "scope_note": "Main process and instrumented threads/libraries; excludes children, kernel, GPU and Xvfb",
               "geometry_scope": "Exact body/post/image bounding rectangles, retained SVG paint-geometry audit and paint-command count; PNGs cover the full viewport",
               "image_policy": "Require every visible image decoded; compare all image source/dimension/state records exactly, retaining unresolved nonvisible images",
               "reference_policy": "Every observation, including the first baseline, must exactly match the pinned first diagnostic PNG and all native audit fields except the explicitly canonicalized repetition count of one native message; that diagnostic Callgrind count is excluded",
               "diagnostic_policy": "A positive list containing only the exact source-proven native shadow message; preserve raw lists/counts/audit hashes and compare a singleton classification. All other/new/changed messages, empty lists and native errors fail",
               "supplementary_control_policy": "The invalid first cohort remains invalid; its pinned, strictly reparsed raw unmodified Cachegrind control additionally tightens a mandatory separate gate, without entering normal pairs or medians",
               "cache_note": "Fresh browser profile/cache and XDG caches per observation; OS filesystem caches retained",
               "retry_policy": "No retries, excluded attempts or replacement observations; stop on first invalid observation",
               "required_reduction_percent": 10, "observations": [], "pairs": [],
               "started_host": host_snapshot()}
    write_json(summary_path, summary)
    transport = None
    try:
        transport = OfflineTransport()
        environment = clean_environment(transport.proxy)
        fixture = fixture_metadata()
        reference = load_reference_capture(args.reference_capture_report, fixture)
        control = load_supplementary_control(fixture, reference)
        if args.counter_backend != control["metadata"]["counter_backend"]:
            raise ValueError("The prospective acceptance cohort and supplementary control must both use Cachegrind")
        binaries = {label: pin_binary(path, environment, args.runtime_library)
                    for label, path in (("baseline", args.baseline), ("candidate", args.candidate))}
        if binaries["baseline"]["sha256"] != reference["metadata"]["baseline_binary_sha256"]:
            raise ValueError("Cohort baseline binary differs from the first diagnostic reference binary")
        if library_content_identity(binaries["baseline"]) != library_content_identity(binaries["candidate"]):
            raise ValueError("Baseline/candidate runtime-library contents differ")
        if library_content_identity(binaries["baseline"]) != control["library_identity"]:
            raise ValueError("Runtime-library contents differ from the supplementary control")
        font_pins = pin_fonts(environment)
        if font_pins != control["fonts"]:
            raise ValueError("Font or fontconfig identities differ from the supplementary control")
        # The non--prod V frontend can reopen embedded resources from the checkout
        # even though its generated C is optimized. Pin those runtime bytes too.
        runtime_assets = pin_files(REPO / path for path in RUNTIME_ASSETS)
        if runtime_assets != control["runtime_assets_sha256"]:
            raise ValueError("Embedded/runtime asset identities differ from the supplementary control")
        tools = pin_files([Path(__file__), WORK / "network_audit.py", DRIVER, REPO / "tools/linux_instruction_counts.py",
                           REPO / "tools/process_instruction_counts.py", AUDIT_CONFIG, EXPECTED_POSTS,
                           EXPECTED_NATIVE_DIAGNOSTICS, WORK / "observer-correction-01/provenance.json",
                           SUPPLEMENTARY_CONTROL, WORK / "observer-correction-02/provenance.json",
                           Path(sys.executable), args.valgrind, Path(shutil.which("xvfb-run")),
                           Path(shutil.which("Xvfb")), Path(shutil.which("fc-list"))])
        all_pins = {**fixture["file_sha256"], **tools, **runtime_assets,
                    **font_pins["files_sha256"], **font_pins["fontconfig_files_sha256"],
                    **reference["file_pins"], **control["file_pins"]}
        for pin in binaries.values():
            all_pins.update(binary_file_pins(pin))
        summary.update(fixture=fixture, binaries=binaries, fonts=font_pins,
                       observer_inputs_sha256=tools, runtime_assets_sha256=runtime_assets,
                       controlled_environment=environment,
                       network_policy={"proxy": transport.proxy, "forwarding": False,
                                       "mechanism": "exclusively bound non-listening loopback TCP port",
                                       "scope": "browsernet and libcurl HTTP(S); file/data remain unchanged",
                                       "bypass_lists": "empty", "applies_to": "both variants"},
                       reference_capture=reference["metadata"],
                       reference_inputs_sha256=reference["file_pins"],
                       supplementary_control=control["metadata"],
                       supplementary_control_inputs_sha256=control["file_pins"],
                       valgrind=control["valgrind"],
                       reference_png=str(reference["png"]),
                       reference_png_sha256=reference["metadata"]["screenshot_file_sha256"],
                       reference_decoded_rgba_sha256=reference["metadata"]["decoded_rgba_sha256"],
                       status="running")
        write_json(args.output / "resource-network-inventory.json", fixture["network_inventory"])
        write_json(args.output / "reference-content-validation.json", reference["document"])
        write_json(summary_path, summary)
        reference_document = reference["document"]
        reference_png = reference["png"]
        reference_png_sha256 = reference["metadata"]["screenshot_file_sha256"]
        valgrind_identity = control["valgrind"]
        for index in range(args.pairs):
            pair = {}
            labels = ("baseline", "candidate") if index % 2 == 0 else ("candidate", "baseline")
            for label in labels:
                verify_files(all_pins)
                if digest(reference_png) != reference_png_sha256:
                    raise ValueError("Pinned first diagnostic reference PNG changed")
                observation = args.output / f"pair-{index + 1:02d}-{label}"
                observation.mkdir(mode=0o700)
                temporary = observation / "tmp"
                temporary.mkdir(mode=0o700)
                env = dict(environment, TMPDIR=str(temporary),
                           XDG_CACHE_HOME=str(temporary / "xdg-cache"),
                           XDG_CONFIG_HOME=str(temporary / "xdg-config"),
                           XDG_DATA_HOME=str(temporary / "xdg-data"))
                prefix = observation / "capture"
                command = ["xvfb-run", "-a", "-s", "-screen 0 1600x1200x24",
                           sys.executable, str(DRIVER), "--engine", "vox", "--counter-backend", args.counter_backend,
                           "--binary", binaries[label]["path"], "--url", fixture["url"],
                           "--width", str(WIDTH), "--height", str(HEIGHT), "--settle-seconds", "0",
                           "--expect-title", TITLE, "--capture-audit-config", str(AUDIT_CONFIG),
                           "--scratch-dir", str(temporary), "--output", str(prefix), "--repeat", "1",
                           "--timeout", str(args.timeout), "--valgrind", str(args.valgrind)]
                for library in sorted(set(binary_file_pins(binaries[label])) - {binaries[label]["path"]}):
                    command += ["--runtime-library", library]
                command += ["--expected-png", str(reference_png)]
                row = {"pair": index + 1, "variant": label, "status": "running",
                       "directory": str(observation), "command": command,
                       "environment": env, "host_before": host_snapshot()}
                summary["observations"].append(row)
                write_json(observation / "invocation.json", row)
                write_json(summary_path, summary)
                print(json.dumps({"status": "running", "pair": index + 1, "variant": label}), flush=True)
                try:
                    with (observation / "driver.log").open("w") as log:
                        result = subprocess.run(command, cwd=REPO, env=env, stdout=log, stderr=subprocess.STDOUT)
                    row.update(driver_exit=result.returncode, host_after=host_snapshot())
                    report_path = Path(str(prefix) + ".run-1.json")
                    row["report"] = str(report_path)
                    if result.returncode != 0:
                        raise RuntimeError("Capture driver failed; see " + str(observation / "driver.log"))
                    report = read_json(report_path)
                    count = report.get("instructions")
                    row["instructions"] = count
                    if (type(count) is not int or count <= 0 or report.get("instruction_metric") != metric
                            or report.get("counter_backend") != args.counter_backend or report.get("hardware_retired") is not False
                            or report.get("exit") != 0 or report.get("root_final_exit_sample") is not True
                            or report.get("binary_sha256") != binaries[label]["sha256"]):
                        raise ValueError("Instruction metric, completion or binary identity gate failed")
                    report_valgrind = report.get("valgrind")
                    if not report_valgrind or not report_valgrind.get("runtime_files_sha256"):
                        raise ValueError("Valgrind runtime identity is missing")
                    if valgrind_identity is None:
                        valgrind_identity = report_valgrind
                        summary["valgrind"] = valgrind_identity
                        all_pins.update(report_valgrind["runtime_files_sha256"])
                    elif valgrind_identity != report_valgrind:
                        raise ValueError("Valgrind executable/runtime identity changed")
                    diagnostics = diagnostic_observation(report["document_audit"], fixture)
                    write_json(observation / "native-diagnostics.json", diagnostics)
                    row.update(native_renderer_diagnostic_count=diagnostics["raw_occurrences"],
                               raw_native_audit_sha256=diagnostics["raw_audit_sha256"])
                    document = validate_document(report["document_audit"], fixture)
                    write_json(observation / "content-validation.json", document)
                    compare_document(reference_document, document, observation)
                    png = Path(report["screenshot"]).resolve()
                    png.relative_to(observation)
                    pixels = report.get("screenshot_validation", {})
                    if (pixels.get("width"), pixels.get("height")) != (WIDTH, HEIGHT):
                        raise ValueError("Viewport pixel dimensions changed")
                    if (pixels.get("exact") is not True
                            or pixels.get("decoded_rgba_sha256") != summary["reference_decoded_rgba_sha256"]
                            or pixels.get("expected_file_sha256") != reference_png_sha256):
                        raise ValueError("Capture is not pixel-exact to the pinned first diagnostic")
                    verify_files(all_pins)
                    if digest(reference_png) != reference_png_sha256:
                        raise ValueError("Pinned reference PNG changed during capture")
                    row.update(status="valid", pixel_exact=True, content_exact=True, geometry_exact=True,
                               content_sha256=object_digest(document),
                               unresolved_nonvisible_images=len(document["unresolved_nonvisible_images"]))
                    pair[label] = {"instructions": count, "report": str(report_path),
                                   "screenshot": str(png), "pixel_exact": True, "content_exact": True,
                                   "geometry_exact": True,
                                   "native_renderer_diagnostic_count": diagnostics["raw_occurrences"]}
                    write_json(observation / "result.json", row)
                    print(json.dumps({"status": "valid", "pair": index + 1, "variant": label,
                                      "instructions": count, "pixel_exact": True, "content_exact": True}), flush=True)
                except BaseException as error:
                    row.update(status="invalid", error=f"{type(error).__name__}: {error}",
                               host_after=host_snapshot())
                    write_json(observation / "result.json", row)
                    write_json(summary_path, summary)
                    raise
                write_json(summary_path, summary)
            summary["pairs"].append(pair)
            write_json(summary_path, summary)
        if len(summary["pairs"]) != args.pairs or len(summary["observations"]) != 2 * args.pairs:
            raise ValueError("Cohort is incomplete")
        normal_statistics = statistics_for_pairs(summary["pairs"])
        extra_gate = supplementary_gate(normal_statistics, control)
        summary.update(normal_statistics)
        summary.update(normal_cohort_target_met=normal_statistics["target_met"],
                       supplementary_conservative_gate=extra_gate,
                       target_met=normal_statistics["target_met"] and extra_gate["target_met"])
        summary.update(status="completed", valid=True, finished_host=host_snapshot())
        write_json(summary_path, summary)
        print(json.dumps({key: summary[key] for key in ("valid", "instruction_metric", "baseline_counts",
              "candidate_counts", "baseline_median", "candidate_median", "median_reduction_percent",
              "conservative_reduction_percent", "normal_cohort_target_met",
              "supplementary_conservative_gate", "target_met")}), flush=True)
        return 0 if summary["target_met"] else 1
    except BaseException as error:
        summary.update(status="invalid", valid=False, target_met=False,
                       error=f"{type(error).__name__}: {error}", finished_host=host_snapshot(),
                       completed_observation_counts=[{"pair": row["pair"], "variant": row["variant"],
                                                      "instructions": row["instructions"], "status": row["status"]}
                                                     for row in summary["observations"] if "instructions" in row])
        write_json(summary_path, summary)
        (args.output / "exception.txt").write_text(traceback.format_exc())
        print(json.dumps({"status": "invalid", "error": summary["error"],
                          "summary": str(summary_path)}), file=sys.stderr, flush=True)
        return 2
    finally:
        if transport is not None:
            transport.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True,
                        help="New evidence directory beneath this repository's Build/")
    parser.add_argument("--reference-capture-report", type=Path, required=True,
                        help="Pinned first diagnostic driver JSON; every observation must match its pixels and complete audit")
    parser.add_argument("--pairs", type=int, default=3)
    parser.add_argument("--counter-backend", choices=("callgrind", "cachegrind"), default="callgrind",
                        help="Explicit metric for the entire cohort; never falls back or mixes counts")
    parser.add_argument("--timeout", type=float, default=1800)
    parser.add_argument("--valgrind", default="valgrind")
    parser.add_argument("--runtime-library", type=Path, action="append", default=[],
                        help="Additional native library to pin (repeatable)")
    args = parser.parse_args()
    if args.pairs < 1 or not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error("pairs and per-observation timeout must be positive")
    if platform.system() != "Linux":
        parser.error("This software-instruction capture protocol requires Linux")
    args.output = args.output.resolve()
    args.reference_capture_report = args.reference_capture_report.resolve()
    if not args.reference_capture_report.is_file():
        parser.error("reference-capture-report must be an existing driver JSON report")
    try:
        args.output.relative_to(BUILD.resolve())
    except ValueError:
        parser.error("All evidence must remain beneath the repository's Build/ directory")
    if args.output.exists():
        parser.error("Output already exists; evidence is never overwritten")
    for name in ("baseline", "candidate"):
        path = getattr(args, name).resolve()
        if not path.is_file() or not os.access(path, os.X_OK):
            parser.error(name + " must be an existing executable")
        setattr(args, name, path)
    for name in ("xvfb-run", "Xvfb", "fc-list", "ldd", args.valgrind):
        if shutil.which(name) is None:
            parser.error("Required executable is unavailable: " + name)
    args.valgrind = Path(shutil.which(args.valgrind)).resolve()
    args.runtime_library = [path.resolve() for path in args.runtime_library]
    return run(args)


if __name__ == "__main__":
    sys.exit(main())
