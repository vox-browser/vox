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

# Without V's -prod, $embed_file payloads can be read from these checkout
# paths at runtime even when the executable itself stays unchanged.
RUNTIME_ASSETS = (
    'adblock/extended/procedural.js', 'url/public_suffix_list_reversed.dat',
    'browserjs/vendor/es-module-lexer-1.7.0/lexer.asm.js',
    'browserhistory/history.css', 'aria/aria_roles.json',
    'dom/resources/pdfjs/viewer.html',
    'optimizedsites/assets/wikipedia.ico', 'optimizedsites/assets/reddit.png',
    'optimizedsites/assets/vlang.png', 'optimizedsites/assets/hacker-news.ico',
    'layout/resources/chromium/broken-image-200.png',
    'layout/resources/chromium/broken-image-100.png',
    'css/ua_default.css', 'css/ua_quirks_mode.css',
    'css/ua_mathml_default.css', 'css/ua_svg_default.css', 'html/media_controls.css',
)


def runtime_input_paths(binary, environment, checkout=REPO):
    paths = [checkout / name for name in RUNTIME_ASSETS]
    paths.append(binary.parent / 'VoxAdblockWorker')
    selected = environment.get('VOX_ADBLOCK_ENGINE_ASSETS')
    if selected:
        directory = Path(selected).resolve()
        for name in ['engine.js.gz', 'engine.snapshot.bin', 'engine.snapshot.json.gz']:
            asset = directory / name
            if not asset.is_file():
                raise ValueError(f'Missing selected adblock runtime asset: {asset}')
            paths.append(asset)
    else:
        resources = binary.parent.parent / 'Resources'
        codec = resources / 'adblock.engine.js.gz'
        metadata = resources / 'adblock.engine.snapshot.json.gz'
        bundled = resources / 'adblock.snapshot.bin'
        if codec.is_file() or metadata.is_file():
            # New bundles select a complete packaged set. Never substitute a
            # checkout member when the selected package is incomplete.
            for asset in [codec, metadata, bundled]:
                if not asset.is_file():
                    raise ValueError(f'Missing packaged adblock runtime asset: {asset}')
                paths.append(asset)
        else:
            # Older bundles package only the snapshot; standalone executables
            # read all three fallback assets from their embedded source paths.
            paths.extend(checkout / 'adblock' / name for name in
                         ['engine.js.gz', 'engine.snapshot.json.gz'])
            paths.append(bundled if bundled.is_file() else checkout / 'adblock/engine.snapshot.bin')
    return sorted({path.resolve() for path in paths if path.is_file()})


def input_file_identity(path):
    value = path.stat()
    return [value.st_dev, value.st_ino, value.st_size, value.st_mtime_ns, value.st_ctime_ns]


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


def verify_native_images(log, binary, native_bridge=None, picture_bridge=None, image_bridge=None):
    images = {}
    for line in log.splitlines():
        if not line.startswith('SCROLL_IMAGE '):
            continue
        match = re.fullmatch(r'SCROLL_IMAGE name=(\S+) path_hex=([0-9a-f]+)', line)
        if not match:
            raise ValueError('Invalid native image identity record')
        name, encoded = match.groups()
        path = Path(os.fsdecode(bytes.fromhex(encoded))).resolve()
        expected = (Path(native_bridge) if native_bridge and name == 'libLadybirdVSkiaText.dylib'
                    else Path(picture_bridge) if picture_bridge and name == 'libVoxGraphiteDawn.dylib'
                    else Path(image_bridge) if image_bridge and name == 'libVoxGraphite.dylib'
                    else binary.parent / name).resolve()
        if name not in {'libLadybirdVSkiaText.dylib', 'libVoxGraphite.dylib',
                        'libVoxGraphiteDawn.dylib'} or path != expected:
            raise ValueError(f'Native image outside selected bundle: {path}; expected {expected}')
        images[name] = str(path)
    if 'libLadybirdVSkiaText.dylib' not in images:
        raise ValueError('Missing native renderer image identity')
    if picture_bridge and 'libVoxGraphiteDawn.dylib' not in images:
        raise ValueError('Missing selected picture renderer image identity')
    if image_bridge and 'libVoxGraphite.dylib' not in images:
        raise ValueError('Missing selected image renderer image identity')
    return images


def intervals(rows):
    values = [b["t_us"] - a["t_us"] for a, b in zip(rows, rows[1:])]
    if not values or min(values) <= 0:
        raise ValueError("Insufficient samples or non-increasing timestamps")
    return values


def summarize(log, expected_inputs, target_hz=60, required_title="", expected_viewport=None):
    # A fault on another thread can race the probe's successful _exit(0)
    # after SCROLL_DONE. A completed input log and zero exit do not erase it.
    if re.search(r"^SCROLL_FAULT_FIRST(?:\s|$)", log, re.MULTILINE):
        raise ValueError("Native fault recorded; measurement is invalid regardless of process exit")
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
    if expected_viewport is not None:
        dimensions = dict(re.findall(r"(document_width|document_height)=([\d.]+)", starts[0]))
        if any(float(dimensions.get(key, "nan")) != expected for key, expected in
               zip(("document_width", "document_height"), expected_viewport)):
            raise ValueError("Observed document viewport differs from requested viewport")
    inputs, frames = records(log, "SCROLL_INPUT"), records(log, "SCROLL_PUBLISH")
    if any(row.get("modifiers", 0) != 0 or row.get("delta_x", 0) != 0 for row in inputs):
        raise ValueError("Modified or horizontal input invalidates a vertical scroll trial")
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
    parser.add_argument("--allow-fixture-navigation", action="store_true",
                        help="Seed only allow_any_site in the private profile for file/loopback fixtures")
    parser.add_argument("--v-profile-reset", action="store_true",
                        help="Diagnostic only: reset v -profile counters immediately before native input")
    parser.add_argument("--capture-faults", action="store_true",
                        help="Diagnostic only: record first-fault registers and bounded readable memory")
    parser.add_argument("--network-policy", required=True,
                        help="Describe live access or supplied network-blocking interposer; recorded verbatim")
    parser.add_argument("--insert-library", action="append", type=Path, default=[])
    parser.add_argument("--native-renderer-bridge", type=Path,
                        help="Explicit unpublished native candidate; require this exact loaded bridge instead of the bundle bridge")
    parser.add_argument("--picture-renderer-bridge", type=Path,
                        help="Explicit unpublished libVoxGraphiteDawn.dylib; pin and require this exact loaded picture renderer")
    parser.add_argument("--image-renderer-bridge", type=Path,
                        help="Explicit unpublished libVoxGraphite.dylib; pin and require this exact loaded image renderer")
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
    fault_header = source.with_name("precise_scroll_faults.h")
    compile_inputs = {path: sha256(path) for path in [source, fault_header]}
    compile_command = ["clang", "-O2", "-Wall", "-Wextra", "-Werror",
                       "-dynamiclib", "-fobjc-arc", str(source),
                       "-framework", "Cocoa", "-framework", "QuartzCore",
                       "-Wl,-undefined,dynamic_lookup", "-o", str(probe)]
    with (output / "compile.log").open("w") as log:
        subprocess.run(compile_command, stdout=log, stderr=subprocess.STDOUT, check=True)
    if compile_inputs != {path: sha256(path) for path in compile_inputs}:
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
    if args.allow_fixture_navigation:
        (profile / "settings.json").write_text('{"allow_any_site":true}\n')
    digest = hashlib.sha256()
    for path in sorted(cache.rglob("*")):
        if path.is_file():
            digest.update(str(path.relative_to(cache)).encode() + b"\0" + path.read_bytes())
    env = dict(os.environ)
    env.update(item.split("=", 1) for item in args.env)
    # A settings file is an explicit proxy override, even when it contains
    # only allow_any_site (its missing enabled field defaults to false).
    # This flag is for file/loopback fixtures, not a replacement for a replay
    # proxy profile. Fail rather than silently bypassing the requested route.
    if args.allow_fixture_navigation and env.get("VOX_PROXY"):
        raise ValueError("--allow-fixture-navigation disables profile proxying; cannot combine with VOX_PROXY")
    # Diagnostic workload changes are forbidden in this acceptance probe.
    for name in list(env):
        if name.startswith(("VOX_PROFILE_", "VOX_SCROLL_PROFILE_")) or name in {
                "VOX_DISABLE_SCROLL_RASTER_REUSE", "LADYBIRD_ENABLE_SNAPSHOT_CACHE",
                "LADYBIRD_SCREENSHOT_DELAY_SECONDS"}:
            env.pop(name)
    libraries = [path.resolve() for path in args.insert_library]
    native_bridge = args.native_renderer_bridge.resolve() if args.native_renderer_bridge else None
    if native_bridge:
        if native_bridge.name != "libLadybirdVSkiaText.dylib" or not native_bridge.is_file():
            parser.error("--native-renderer-bridge must name an existing libLadybirdVSkiaText.dylib")
        if native_bridge not in libraries:
            libraries.insert(0, native_bridge)
    picture_bridge = args.picture_renderer_bridge.resolve() if args.picture_renderer_bridge else None
    if picture_bridge:
        if picture_bridge.name != "libVoxGraphiteDawn.dylib" or not picture_bridge.is_file():
            parser.error("--picture-renderer-bridge must name an existing libVoxGraphiteDawn.dylib")
        if picture_bridge not in libraries:
            libraries.insert(0, picture_bridge)
    image_bridge = args.image_renderer_bridge.resolve() if args.image_renderer_bridge else None
    if image_bridge:
        if image_bridge.name != "libVoxGraphite.dylib" or not image_bridge.is_file():
            parser.error("--image-renderer-bridge must name an existing libVoxGraphite.dylib")
        if image_bridge not in libraries:
            libraries.insert(0, image_bridge)
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
               VOX_PRECISE_RESET_V_PROFILE="1" if args.v_profile_reset else "",
               VOX_PRECISE_CAPTURE_FAULTS="1" if args.capture_faults else "",
               VOX_PRECISE_FAILURE_CAPTURE=str(output / "navigation-error.png"),
               VOX_PRECISE_REQUIRED_TITLE=args.require_title)
    pinned = [binary, *sorted(binary.parent.glob("*.dylib")),
              Path(__file__).resolve(), source, fault_header, probe, *libraries]
    runtime_paths = runtime_input_paths(binary, env)
    pinned.extend(runtime_paths)
    # A private replay certificate changes the accepted network responses.
    # Retain its identity with the code, rather than just a mutable pathname.
    if env.get("SSL_CERT_FILE"):
        certificate = Path(env["SSL_CERT_FILE"]).resolve()
        if certificate.is_file():
            pinned.append(certificate)
    hashes = {str(path): sha256(path) for path in pinned}
    file_identities = {str(path): input_file_identity(path) for path in pinned}
    script_flags = {"automatic": [], "enabled": ["--enable-javascript"],
                    "disabled": ["--disable-javascript"]}[args.script_policy]
    command = [str(binary), *script_flags, "--window-width", str(args.width),
               "--window-height", str(args.height + args.chrome_height), args.url]
    evidence = dict(command=command, compile_command=compile_command,
                    diagnostic_only=args.v_profile_reset or args.capture_faults,
                    source_and_binary_sha256=hashes, cache_sha256=digest.hexdigest(),
                    runtime_input_sha256={str(path): hashes[str(path)] for path in runtime_paths},
                    input_file_identity=file_identities,
                    initial_profile=("private profile seeded only with allow_any_site=true; "
                                     "default bookmark bar; explicit direct networking"
                                     if args.allow_fixture_navigation else
                                     "empty private profile; default bookmark bar; no saved proxy override"),
                    native_configuration="explicit unpublished native candidate" if native_bridge or picture_bridge or image_bridge else "installed bundle",
                    native_renderer_bridge=str(native_bridge) if native_bridge else None,
                    picture_renderer_bridge=str(picture_bridge) if picture_bridge else None,
                    image_renderer_bridge=str(image_bridge) if image_bridge else None,
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
        if (hashes != {str(path): sha256(path) for path in pinned}
                or file_identities != {str(path): input_file_identity(path) for path in pinned}):
            raise RuntimeError("Build, runtime asset or probe identity changed during measurement")
        browser_log = (output / "browser.log").read_text(errors="replace")
        evidence['native_fault_recorded'] = bool(re.search(
            r'^SCROLL_FAULT_FIRST(?:\s|$)', browser_log, re.MULTILINE))
        evidence['native_images'] = verify_native_images(browser_log, binary, native_bridge, picture_bridge, image_bridge)
        if any(path not in hashes for path in evidence['native_images'].values()):
            raise RuntimeError('Loaded native image was not pinned before launch')
        summary = summarize(browser_log,
                            args.inputs, args.target_hz, args.require_title, (args.width, args.height))
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
