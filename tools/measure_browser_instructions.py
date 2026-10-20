#!/usr/bin/env python3
"""Measure browser CPU instructions through a rendered document capture.

Vox additionally reports exact in-process installation/first-frame intervals.
Chrome uses an isolated profile and includes observed renderer/GPU/utility tasks.
Elapsed time is used only as a watchdog, never as the reported work metric.
"""
import argparse
import base64
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import signal
import socket
import statistics
import struct
import subprocess
import tempfile
import time
import urllib.parse
import urllib.request

from process_instruction_counts import MacCounters, ProcessTreeCounter, CounterSampler

REPO = Path(__file__).resolve().parents[1]
VOX_TOOLBAR_HEIGHT = 60
VOX_CHROME_HEIGHT = VOX_TOOLBAR_HEIGHT + 24


def fingerprint_files(paths):
    """Pin mutable non-system runtime inputs outside the measured interval."""
    return {str(path.resolve()): {"sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                                "bytes": path.stat().st_size} for path in paths}


def chrome_launch_command(args, binary, profile):
    if (getattr(args, "chrome_disable_javascript", False)
            and getattr(args, "chrome_launch_mode", "blank") == "direct"):
        raise ValueError("Disabling Chrome author JavaScript requires blank launch so the policy precedes navigation")
    command = [str(binary), "--headless=new", "--no-first-run", "--no-default-browser-check",
               "--disable-background-networking", "--remote-debugging-port=0",
               f"--user-data-dir={profile}"]
    command.extend(getattr(args, "chrome_extra_arg", []))
    if getattr(args, "chrome_launch_mode", "blank") == "direct":
        command += [f"--window-size={args.width},{args.chrome_outer_window_height}", args.url]
    else:
        command.append("about:blank")
    return command


def prepare_chrome_target(client, args):
    if getattr(args, "chrome_launch_mode", "blank") == "direct":
        return None
    version = client.call("Browser.getVersion")
    client.call("Page.enable")
    client.call("Runtime.enable")
    client.call("Emulation.setDeviceMetricsOverride", {
        "width": args.width, "height": args.height, "deviceScaleFactor": 1, "mobile": False})
    if getattr(args, "chrome_disable_javascript", False):
        client.call("Emulation.setScriptExecutionDisabled", {"value": True})
    return version


def validate_direct_chrome_viewport(args, document):
    actual = document.get("width"), document.get("height"), document.get("scale")
    expected = args.width, args.height, 1
    if actual != expected:
        raise RuntimeError(f"Direct Chrome viewport is {actual}; expected {expected}. "
                           "Calibrate --chrome-outer-window-height before measuring; "
                           "the direct mode never resizes the document.")


def chrome_debugger_endpoint(active):
    """Chrome may create its discovery file before either line is written."""
    try:
        lines = active.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError):
        return None
    if len(lines) < 2 or not re.fullmatch(r"[0-9]+", lines[0]):
        return None
    port, browser_path = int(lines[0]), lines[1]
    prefix = "/devtools/browser/"
    if (not 0 < port < 65536 or not browser_path.startswith(prefix)
            or len(browser_path) == len(prefix) or any(c.isspace() for c in browser_path)):
        return None
    return port, browser_path


def wait_for_chrome_debugger(active, counter, deadline, interval, log_path):
    while True:
        endpoint = chrome_debugger_endpoint(active)
        if endpoint is not None:
            return endpoint
        if time.monotonic() > deadline:
            raise RuntimeError("Chrome debugger did not start before the watchdog")
        root = counter.sample().get(counter.root_identity)
        if root and root.exited:
            raise RuntimeError(f"Chrome exited before debugger startup; see {log_path}")
        time.sleep(interval)


def wait_for_chrome_page_target(opener, port, counter, deadline, interval, log_path):
    # The debugger can publish its port before the initial page target exists.
    # Keep counting this same process while waiting for its actual readiness.
    while True:
        with opener.open(f"http://127.0.0.1:{port}/json/list", timeout=15) as response:
            targets = json.load(response)
        for target in targets:
            if target.get('type') == 'page' and target.get('webSocketDebuggerUrl'):
                return target['webSocketDebuggerUrl']
        if time.monotonic() > deadline:
            raise RuntimeError('Chrome page target did not start before the watchdog')
        readings = counter.sample()
        root = readings.get(counter.root_identity)
        if root and root.exited:
            raise RuntimeError(f'Chrome exited before page target startup; see {log_path}')
        time.sleep(interval)


class CDP:
    def __init__(self, url):
        parsed = urllib.parse.urlparse(url)
        self.sock = socket.create_connection((parsed.hostname, parsed.port), timeout=15)
        self.sock.settimeout(15)
        self.pending = bytearray()
        self.sequence = 0
        key = base64.b64encode(os.urandom(16)).decode()
        request = (f"GET {parsed.path} HTTP/1.1\r\nHost: {parsed.hostname}:{parsed.port}\r\n"
                   f"Upgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: {key}\r\n"
                   "Sec-WebSocket-Version: 13\r\n\r\n")
        self.sock.sendall(request.encode())
        while b"\r\n\r\n" not in self.pending:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise EOFError("CDP connection closed during handshake")
            self.pending.extend(chunk)
        header, rest = bytes(self.pending).split(b"\r\n\r\n", 1)
        if header.split(b"\r\n", 1)[0].split()[1] != b"101":
            raise RuntimeError(header.decode())
        self.pending = bytearray(rest)

    def read(self, count):
        while len(self.pending) < count:
            chunk = self.sock.recv(max(4096, count - len(self.pending)))
            if not chunk:
                raise EOFError("CDP connection closed")
            self.pending.extend(chunk)
        result = bytes(self.pending[:count])
        del self.pending[:count]
        return result

    def send(self, body, opcode=1):
        size = len(body)
        header = bytes([0x80 | opcode, 0x80 | (size if size < 126 else 126 if size <= 65535 else 127)])
        if size >= 126:
            header += struct.pack("!H" if size <= 65535 else "!Q", size)
        mask = os.urandom(4)
        self.sock.sendall(header + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(body)))

    def receive(self):
        parts = []
        while True:
            flags, length = self.read(2)
            opcode = flags & 15
            count = length & 127
            if count == 126:
                count = struct.unpack("!H", self.read(2))[0]
            elif count == 127:
                count = struct.unpack("!Q", self.read(8))[0]
            mask = self.read(4) if length & 128 else None
            body = self.read(count)
            if mask:
                body = bytes(b ^ mask[i % 4] for i, b in enumerate(body))
            if opcode == 8:
                raise EOFError("CDP connection closed")
            if opcode == 9:
                self.send(body, 10)
                continue
            if opcode == 10:
                continue
            parts.append(body)
            if flags & 128:
                return json.loads(b"".join(parts))

    def call(self, method, params=None):
        self.sequence += 1
        self.send(json.dumps({"id": self.sequence, "method": method, "params": params or {}}).encode())
        while True:
            response = self.receive()
            if response.get("id") == self.sequence:
                if "error" in response:
                    raise RuntimeError(response["error"])
                return response.get("result", {})


def parse_native_counters(text):
    phases, scopes, unavailable = [], {}, []
    previous = 0
    for line in text.splitlines():
        match = re.fullmatch(r"Vox instructions (cumulative|scope): (.*?) (\d+)", line)
        if match:
            kind, label, number = match.groups()
            value = int(number)
            if kind == "scope":
                scopes.setdefault(label, []).append(value)
            else:
                if value < previous:
                    raise RuntimeError("Native cumulative instruction counter decreased")
                phases.append({"label": label, "instructions": value - previous,
                               "cumulative_instructions": value})
                previous = value
        elif line.startswith("Vox instructions unavailable:"):
            unavailable.append(line)
    return {"phases": phases, "scopes": scopes, "unavailable": unavailable,
            "phase_note": "adjacent cumulative checkpoint deltas; nested scopes overlap and must not be summed"}


def stop_process(process):
    if process.poll() is None:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        except PermissionError:
            # A native capture may exit between poll and killpg. A remaining
            # system-owned crash reporter does not make that browser alive.
            if process.poll() is None:
                raise
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()


def crop_document_viewport(window, screenshot, width, height):
    # Match capture_screenshot.sh: 56px toolbar (diagnostics hidden), 24px status bar, Retina scale.
    header = window.read_bytes()[:24]
    if header[:8] != b"\x89PNG\r\n\x1a\n" or len(header) != 24:
        raise RuntimeError(f"Invalid native PNG: {window}")
    pixels_wide, pixels_high = struct.unpack("!II", header[16:24])
    scale = pixels_wide // width
    if scale < 1 or pixels_wide % width or (VOX_TOOLBAR_HEIGHT + height) * scale > pixels_high:
        raise RuntimeError("Native capture does not contain the requested document viewport")
    subprocess.run(["sips", "--cropToHeightWidth", str(height * scale), str(width * scale),
                    "--cropOffset", str(VOX_TOOLBAR_HEIGHT * scale), "0", str(window), "--out", str(screenshot)],
                   check=True, stdout=subprocess.DEVNULL)
    if scale != 1:
        subprocess.run(["sips", "--resampleHeightWidth", str(height), str(width), str(screenshot)],
                       check=True, stdout=subprocess.DEVNULL)


@contextmanager
def fresh_vox_cache(template, scratch_dir=None):
    """Copy and fingerprint input outside the measured browser process."""
    if template is None:
        yield None, None
        return
    with tempfile.TemporaryDirectory(prefix="vox-instruction-cache-", dir=scratch_dir) as temporary:
        cache = Path(temporary) / "cache"
        shutil.copytree(template, cache)
        digest = hashlib.sha256()
        for path in sorted(cache.rglob("*")):
            if path.is_file():
                digest.update(str(path.relative_to(cache)).encode() + b"\0" + path.read_bytes())
        yield cache, digest.hexdigest()


def vox_launch_command(args, binary, window_screenshot):
    return [str(binary), *getattr(args, "vox_arg", []),
            "--window-width", str(args.width), "--window-height", str(args.height + VOX_CHROME_HEIGHT),
            "--screenshot", str(window_screenshot), args.url]


def run_vox(args, prefix, api, cache_dir=None):
    binary = args.binary or REPO / "Build/v/Vox.app/Contents/MacOS/Vox"
    screenshot = Path(str(prefix) + ".png")
    window_screenshot = Path(str(prefix) + ".window.png")
    window_screenshot.unlink(missing_ok=True)
    log_path = Path(str(prefix) + ".log")
    env = dict(os.environ, VOX_PROFILE_INSTRUCTIONS="1", LADYBIRD_SCREENSHOT_DELAY_SECONDS="0")
    if cache_dir is not None:
        env["LADYBIRD_CACHE_DIR"] = str(cache_dir)
    env.pop("LADYBIRD_DEBUG_TIMING", None)
    env.pop("GC_PRINT_STATS", None)
    command = vox_launch_command(args, binary, window_screenshot)
    with log_path.open("w") as log:
        launched_at = time.monotonic()
        process = subprocess.Popen(command, cwd=REPO, env=env, stdout=log, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        counter = ProcessTreeCounter(api, process.pid)
        try:
            deadline = time.monotonic() + args.timeout
            while True:
                readings = counter.sample()
                root = readings.get(counter.root_identity)
                if root and root.exited:
                    report = counter.report()
                    break
                if time.monotonic() > deadline:
                    raise RuntimeError("Vox did not finish its document capture before the watchdog")
                time.sleep(getattr(args, "sample_interval", .02))
            # Read the exact root's zombie counters before wait() reaps it.
            code = process.wait()
            endpoint_at = time.monotonic()
        finally:
            stop_process(process)
    if code != 0 or not window_screenshot.exists():
        raise RuntimeError(f"Vox capture failed (exit {code}); see {log_path}")
    # Cropping runs in the observer after the browser's final counter sample.
    crop_document_viewport(window_screenshot, screenshot, args.width, args.height)
    report.update(engine="vox", binary=str(binary), endpoint="process exit after native document capture",
                  url=args.url, viewport=[args.width, args.height], exit=code,
                  command=command,
                  process_launch_to_capture_observed_ms=(endpoint_at - launched_at) * 1000,
                  endpoint_note="includes native capture and process teardown; counters are read from the unreaped root zombie",
                  native=parse_native_counters(log_path.read_text()), screenshot=str(screenshot),
                  native_window_screenshot=str(window_screenshot))
    return report


def run_chrome(args, prefix, api, client_factory=None):
    binary = args.binary or Path("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
    screenshot = Path(str(prefix) + ".png")
    log_path = Path(str(prefix) + ".log")
    direct = getattr(args, "chrome_launch_mode", "blank") == "direct"
    with tempfile.TemporaryDirectory(prefix="vox-chrome-instructions-", dir=args.scratch_dir) as profile:
        command = chrome_launch_command(args, binary, profile)
        with log_path.open("w") as log:
            launched_at = time.monotonic()
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            counter = ProcessTreeCounter(api, process.pid)
            client = None
            try:
                with CounterSampler(counter, getattr(args, "sample_interval", .02)):
                    active = Path(profile) / "DevToolsActivePort"
                    deadline = time.monotonic() + args.timeout
                    port, _ = wait_for_chrome_debugger(
                        active, counter, deadline,
                        getattr(args, "sample_interval", .02) if direct else .02, log_path)
                    # CDP loopback traffic must not use an ambient HTTP proxy.
                    local_http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
                    page_url = wait_for_chrome_page_target(local_http, port, counter, deadline,
                        getattr(args, "sample_interval", .02), log_path)
                    client = (client_factory or CDP)(page_url)
                    version = prepare_chrome_target(client, args)
                    baseline, navigation_at = None, None
                    if not direct:
                        baseline = counter.sample()
                        navigation_at = time.monotonic()
                        client.call("Page.navigate", {"url": args.url})
                    expression = r'''JSON.stringify({title:document.title,url:location.href,
                        ready:document.readyState,textLength:document.body?.innerText.length||0,
                        sprites:document.querySelectorAll('.sprite').length,
                        fileLinks:[...document.querySelectorAll('a')].filter(a=>/\/vlang\/v\/(blob|tree)\//.test(a.href)).length})'''
                    if direct:
                        expression = r'''JSON.stringify({ready:document.readyState,
                            textLength:document.body?.innerText.length||0,
                            sprites:document.querySelectorAll('.sprite').length,
                            width:innerWidth,height:innerHeight,outerWidth:outerWidth,
                            outerHeight:outerHeight,scale:devicePixelRatio,
                            focused:document.hasFocus(),activeTag:document.activeElement?.tagName})'''
                        if urllib.parse.urlparse(args.url).hostname == "github.com":
                            expression = expression[:-2] + r''',fileLinks:[...document.querySelectorAll('a')].filter(a=>/\/vlang\/v\/(blob|tree)\//.test(a.href)).length})'''
                    while True:
                        evaluated = client.call("Runtime.evaluate", {"expression": expression, "returnByValue": True})
                        value = evaluated.get("result", {}).get("value")
                        document = json.loads(value) if value else {}
                        github = urllib.parse.urlparse(args.url).hostname == "github.com" and "/vlang/v" in args.url
                        if (document.get("ready") == "complete" and document.get("textLength", 0) > 0
                                and (not github or document.get("fileLinks", 0) > 0)
                                and (getattr(args, "expect_sprites", None) is None
                                     or document.get("sprites") == args.expect_sprites)
                                and (getattr(args, "expect_text_length", None) is None
                                     or document.get("textLength") == args.expect_text_length)):
                            if direct:
                                validate_direct_chrome_viewport(args, document)
                            break
                        if time.monotonic() > deadline:
                            raise RuntimeError("Chrome did not load document content before the watchdog")
                        time.sleep(getattr(args, "sample_interval", .02) if direct else .02)
                    client.call("Runtime.evaluate", {"expression": "document.fonts.ready.then(()=>true)",
                                                     "awaitPromise": True, "returnByValue": True})
                    data = client.call("Page.captureScreenshot", {"format": "png", "captureBeyondViewport": False})["data"]
                    endpoint_at = time.monotonic()
                    # Use only a complete polling pass BEFORE this response.
                    # A new report() sample would charge later Chrome work and
                    # would not be a lower bound at the stated endpoint.
                    endpoint_snapshot = counter.snapshot_before(endpoint_at)
                    navigation_report = (counter.report(baseline, snapshot=endpoint_snapshot)
                                         if baseline is not None else None)
                    report = counter.report(snapshot=endpoint_snapshot)
                    # Asset auditing happens after the instruction boundary.
                    audited = client.call("Runtime.evaluate", {"expression": r'''JSON.stringify({
                        title:document.title,url:location.href,ready:document.readyState,
                        textLength:document.body?.innerText.length||0,sprites:document.querySelectorAll('.sprite').length,
                        bodyClass:document.body?.className,
                        images:[...document.images].map(i=>({src:i.currentSrc||i.src,complete:i.complete,
                            naturalWidth:i.naturalWidth,naturalHeight:i.naturalHeight,
                            width:i.getBoundingClientRect().width,height:i.getBoundingClientRect().height})),
                        resources:performance.getEntriesByType('resource').map(r=>r.toJSON()),
                        navigation:performance.getEntriesByType('navigation').map(r=>r.toJSON()),
                        paint:performance.getEntriesByType('paint').map(r=>r.toJSON())})''',
                        "returnByValue": True})
                    document_audit = json.loads(audited["result"]["value"])
                    if version is None:
                        version = client.call("Browser.getVersion")
                    screenshot.write_bytes(base64.b64decode(data))
                    report.update(engine="chrome", binary=str(binary), version=version,
                                  endpoint="completed document and first CDP screenshot response",
                                  url=args.url, viewport=[args.width, args.height],
                                  command=command,
                                  chrome_launch_mode="direct" if direct else "blank",
                                  author_javascript_enabled=not getattr(args, "chrome_disable_javascript", False),
                                  author_javascript_policy=("disabled by CDP before Page.navigate; observer Runtime.evaluate remains enabled"
                                      if getattr(args, "chrome_disable_javascript", False) else "browser default"),
                                  process_launch_to_capture_observed_ms=(endpoint_at - launched_at) * 1000,
                                  final_sample_precedes_capture_ms=(endpoint_at - endpoint_snapshot.sampled_at) * 1000,
                                  endpoint_note="observed counters from the last complete sampling pass before screenshot response; omit subsequent audit and browser shutdown",
                                  document_audit=document_audit,
                                  document=document,
                                  screenshot=str(screenshot))
                    if navigation_report is not None:
                        report["navigation_to_screenshot"] = navigation_report
                        report["navigation_to_capture_observed_ms"] = (endpoint_at - navigation_at) * 1000
                    try:
                        client.call("Browser.close")
                    except (EOFError, OSError):
                        pass
            finally:
                if client:
                    client.sock.close()
                stop_process(process)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", choices=["vox", "chrome"], default="vox")
    parser.add_argument("--binary", type=Path)
    parser.add_argument("--vox-arg", action="append", default=[],
                        help="Vox only: repeat to pass literal launch arguments before capture options/URL; use --vox-arg=--enable-javascript for option values")
    parser.add_argument("--url", default="https://github.com/vlang/v")
    parser.add_argument("--output", type=Path, default=REPO / "Build/instructions/github")
    parser.add_argument("--repeat", type=int, default=1)
    parser.add_argument("--width", type=int, default=1024)
    parser.add_argument("--height", type=int, default=768)
    parser.add_argument("--timeout", type=float, default=90)
    parser.add_argument("--scratch-dir", type=Path)
    parser.add_argument("--chrome-launch-mode", choices=["blank", "direct"], default="blank",
                        help="blank preserves historical CDP setup/navigation; direct launches the URL without resizing or navigating")
    parser.add_argument("--chrome-disable-javascript", action="store_true",
                        help="Chrome blank launch only: disable author script execution before navigation; observer CDP evaluation remains enabled")
    parser.add_argument("--chrome-outer-window-height", type=int,
                        help="direct mode: calibrated initial outer height yielding the requested document viewport")
    parser.add_argument("--sample-interval", type=float, default=.005,
                        help="seconds between process-tree counter polls; observer work is excluded")
    parser.add_argument("--expect-sprites", type=int,
                        help="Chrome: require this many .sprite elements before capturing")
    parser.add_argument("--expect-text-length", type=int,
                        help="Chrome: require this exact body innerText length before capturing")
    parser.add_argument("--runtime-library", type=Path, action="append", default=[],
                        help="pin this non-system runtime library before and after each run; may repeat")
    parser.add_argument("--cache-template", type=Path,
                        help="Vox only: start every run with a fresh copy of this page/resource cache")
    args = parser.parse_args()
    if args.repeat < 1 or args.timeout <= 0 or args.width < 1 or args.height < 1 or args.sample_interval <= 0:
        parser.error("repeat, dimensions, and watchdog must be positive")
    if args.vox_arg and args.engine != "vox":
        parser.error("--vox-arg requires engine vox")
    if args.chrome_disable_javascript and (args.engine != "chrome" or args.chrome_launch_mode != "blank"):
        parser.error("--chrome-disable-javascript requires engine chrome and blank launch so the policy precedes navigation")
    if args.chrome_launch_mode == "direct":
        if args.engine != "chrome" or not args.chrome_outer_window_height or args.chrome_outer_window_height <= 0:
            parser.error("direct launch requires engine chrome and a positive --chrome-outer-window-height")
    elif args.chrome_outer_window_height is not None:
        parser.error("--chrome-outer-window-height requires --chrome-launch-mode direct")
    if args.binary:
        args.binary = args.binary.resolve()
    if args.cache_template:
        if args.engine != "vox" or not args.cache_template.is_dir():
            parser.error("cache-template requires engine vox and an existing directory")
        args.cache_template = args.cache_template.resolve()
    local = Path(args.url)
    if local.is_file():
        args.url = local.resolve().as_uri()
    args.output = args.output.resolve()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    api = MacCounters()
    runs = []
    for index in range(args.repeat):
        prefix = Path(str(args.output) + f".run-{index + 1}")
        binary = args.binary or (REPO / "Build/v/Vox.app/Contents/MacOS/Vox" if args.engine == "vox"
                                 else Path("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"))
        binary_before = hashlib.sha256(binary.read_bytes()).hexdigest()
        runtime_before = fingerprint_files(args.runtime_library)
        with fresh_vox_cache(args.cache_template, args.scratch_dir) as (cache, template_hash):
            result = (run_vox(args, prefix, api, cache) if args.engine == "vox"
                      else run_chrome(args, prefix, api))
            if template_hash is not None:
                result["cache_template_sha256"] = template_hash
        result["binary_sha256"] = hashlib.sha256(Path(result["binary"]).read_bytes()).hexdigest()
        if result["binary_sha256"] != binary_before:
            raise RuntimeError("Measured executable changed during capture")
        result["runtime_libraries"] = fingerprint_files(args.runtime_library)
        if result["runtime_libraries"] != runtime_before:
            raise RuntimeError("Measured runtime library changed during capture")
        result["measurement_driver_sha256"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        result["counter_module_sha256"] = hashlib.sha256((REPO / "tools/process_instruction_counts.py").read_bytes()).hexdigest()
        result["sample_interval_seconds"] = args.sample_interval
        result["screenshot_sha256"] = hashlib.sha256(Path(result["screenshot"]).read_bytes()).hexdigest()
        Path(str(prefix) + ".json").write_text(json.dumps(result, indent=2) + "\n")
        runs.append(result)
        print(json.dumps({"run": index + 1, "engine": args.engine,
                          "observed_process_tree_instructions": result["instructions"],
                          "aggregate_is_lower_bound": result["aggregate_is_lower_bound"],
                          "root_instructions": result["root_instructions"],
                          "root_final_exit_sample": result["root_final_exit_sample"],
                          "root_lifetime_max_phys_footprint": result["root_lifetime_max_phys_footprint"],
                          "missing_final_sample_count": result["missing_final_sample_count"],
                          "native_scopes": result.get("native", {}).get("scopes"),
                          "navigation_to_screenshot_instructions": result.get("navigation_to_screenshot", {}).get("instructions")}), flush=True)
    summary = {"machine": platform.machine(), "kernel": platform.release(), "engine": args.engine,
               "aggregate_is_lower_bound": True,
               "median_observed_process_tree_instructions": statistics.median(r["instructions"] for r in runs),
               "median_root_instructions": statistics.median(r["root_instructions"] for r in runs), "runs": runs}
    Path(str(args.output) + ".json").write_text(json.dumps(summary, indent=2) + "\n")


if __name__ == "__main__":
    main()
