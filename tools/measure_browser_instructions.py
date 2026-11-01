#!/usr/bin/env python3
"""Measure browser instructions through a rendered document capture.

Vox additionally reports exact in-process installation/first-frame intervals.
Chrome uses an isolated profile and includes observed renderer/GPU/utility tasks.
Elapsed time is used only as a watchdog, never as the reported work metric.
Linux supports perf hardware counters and explicitly selected Callgrind Ir;
software instruction references are never reported as hardware-retired work.
"""
import argparse
import base64
from contextlib import contextmanager
import hashlib
import json
import math
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
from linux_instruction_counts import run_perf_command, run_callgrind_command, run_cachegrind_command

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
            # Cocoa may already be tearing down the process group after a
            # capture. Fall back to the exact Popen child, never another group.
            if process.poll() is None:
                process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except PermissionError:
                process.kill()
            process.wait()


def finish_chrome_capture(client, process, report, prefix, timeout=5):
    """Verify shutdown after freezing counters at the screenshot response.

    Closing the CDP socket can race a successful Browser.close. Wait for the
    actual child instead of immediately signalling it or assuming exit zero.
    Preserve the captured counters if a crash or forced cleanup invalidates it.
    """
    try:
        client.call("Browser.close")
    except (EOFError, OSError):
        pass
    report["shutdown_forced"] = False
    try:
        report["exit"] = process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        report["shutdown_forced"] = True
        stop_process(process)
        report["exit"] = process.poll()
    if type(report["exit"]) is not int or report["exit"] != 0 or report["shutdown_forced"]:
        failure = Path(str(prefix) + ".failure.json")
        if failure.exists():
            failure = Path(str(prefix) + f".failure-{time.time_ns()}.json")
        with failure.open("x") as destination:
            destination.write(json.dumps(dict(report, valid=False), indent=2) + "\n")
        raise RuntimeError(f"Chrome capture shutdown failed (exit {report['exit']}, "
                           f"forced={report['shutdown_forced']}); retained counters in {failure}")


def crop_document_viewport(window, screenshot, width, height):
    # Match capture_screenshot.sh: 56px toolbar (diagnostics hidden), 24px status bar, Retina scale.
    header = window.read_bytes()[:24]
    if header[:8] != b"\x89PNG\r\n\x1a\n" or len(header) != 24:
        raise RuntimeError(f"Invalid native PNG: {window}")
    pixels_wide, pixels_high = struct.unpack("!II", header[16:24])
    scale = pixels_wide // width
    if scale < 1 or pixels_wide % width or (VOX_TOOLBAR_HEIGHT + height) * scale > pixels_high:
        raise RuntimeError("Native capture does not contain the requested document viewport")
    if platform.system() == "Linux":
        from PIL import Image
        with Image.open(window) as captured:
            captured.load()
            viewport = captured.convert("RGBA").crop(
                (0, VOX_TOOLBAR_HEIGHT * scale, width * scale,
                 (VOX_TOOLBAR_HEIGHT + height) * scale))
            if scale != 1:
                viewport = viewport.resize((width, height), Image.Resampling.LANCZOS)
            viewport.save(screenshot)
        return
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
    command = [str(binary), *getattr(args, "vox_arg", []),
            "--window-width", str(args.width), "--window-height", str(args.height + VOX_CHROME_HEIGHT),
            "--screenshot", str(window_screenshot), args.url]
    if getattr(args, "counter_backend", None) in ("linux-perf", "callgrind", "cachegrind"):
        # Pin layout geometry as well as the X11 drawable's outer dimensions.
        command[1:1] = ["--screenshot-viewport-height", str(args.height)]
    return command


def validate_capture_audit(audit, args):
    if audit.get("url") != args.url:
        raise RuntimeError(f"Captured document URL {audit.get('url')!r} differs from {args.url!r}")
    if audit.get("ready") != "complete" or not audit.get("fully_active"):
        raise RuntimeError("Captured document is not complete and fully active")
    if (audit.get("viewport_width"), audit.get("viewport_height")) != (args.width, args.height):
        raise RuntimeError("Captured document viewport differs from requested geometry")
    if audit.get("paint_commands", 0) <= 0:
        raise RuntimeError("Captured document has no paint commands")
    title = getattr(args, "expect_title", None)
    if title is not None and audit.get("title") != title:
        raise RuntimeError(f"Captured document title differs from expected {title!r}")


def validate_screenshot(path, expected, width, height):
    from PIL import Image
    with Image.open(path) as raw:
        raw.load()
        actual = raw.convert("RGBA")
    if actual.size != (width, height):
        raise RuntimeError("Decoded screenshot dimensions differ from requested viewport")
    result = {"width": width, "height": height,
              "decoded_rgba_sha256": hashlib.sha256(actual.tobytes()).hexdigest()}
    if expected is not None:
        with Image.open(expected) as raw:
            raw.load()
            reference = raw.convert("RGBA")
        if reference.size != actual.size or actual.tobytes() != reference.tobytes():
            raise RuntimeError(f"Rendered pixels differ from {expected}")
        result.update(expected=str(expected), exact=True,
                      expected_file_sha256=hashlib.sha256(Path(expected).read_bytes()).hexdigest())
    return result


def capture_settle_seconds(args):
    seconds = float(getattr(args, 'settle_seconds', 0))
    if not math.isfinite(seconds) or not 0 <= seconds < args.timeout:
        raise ValueError('Capture settlement must be finite, nonnegative and below the watchdog')
    return seconds


def native_capture_environment(args, cache_dir=None):
    env = dict(os.environ, LADYBIRD_SCREENSHOT_DELAY_SECONDS=str(capture_settle_seconds(args)))
    if getattr(args, 'native_instruction_markers', True):
        env['VOX_PROFILE_INSTRUCTIONS'] = '1'
    else:
        # Empty values still enable native getenv() checks. Remove the key.
        env.pop('VOX_PROFILE_INSTRUCTIONS', None)
    if cache_dir is not None:
        env['LADYBIRD_CACHE_DIR'] = str(cache_dir)
    env.pop('LADYBIRD_DEBUG_TIMING', None)
    env.pop('GC_PRINT_STATS', None)
    return env


def validate_linux_renderer_log(path):
    errors = []
    count = 0
    with Path(path).open(encoding="utf-8", errors="replace") as log:
        for line in log:
            # Sokol levels are panic=0, error=1, warning=2, info=3. A missing
            # X11 DPI property is merely a warning; invalid image/sampler
            # bindings can silently omit content despite a successful PNG.
            if re.search(r"const_tag: (?:sg|sapp), level: [01],", line):
                count += 1
                if len(errors) < 3:
                    errors.append(line.partition("message: ")[2].strip() or line.strip())
    if count:
        raise RuntimeError(f"Linux renderer reported {count} Sokol errors: "
                           + "; ".join(errors) + f"; see {path}")


def run_vox_linux(args, prefix, cache_dir=None):
    binary = args.binary or REPO / "Build/linux/vox"
    screenshot = Path(str(prefix) + ".png")
    window = Path(str(prefix) + ".window.png")
    audit_path = Path(str(prefix) + ".audit.json")
    log_path = Path(str(prefix) + ".log")
    # Reject before touching anything: completed and failed observations are
    # evidence, and an old PNG/audit must never validate a new empty capture.
    if list(prefix.parent.glob(prefix.name + ".*")):
        raise RuntimeError("Capture evidence already exists for this prefix; use a new output prefix")
    command = vox_launch_command(args, binary, window)
    with tempfile.TemporaryDirectory(prefix="vox-linux-profile-", dir=getattr(args, "scratch_dir", None)) as temporary:
        profile = Path(temporary) / "profile"
        profile.mkdir()
        cache = cache_dir or Path(temporary) / "cache"
        cache.mkdir(exist_ok=True)
        env = dict(os.environ, VOX_PROFILE_DIR=str(profile), LADYBIRD_CACHE_DIR=str(cache),
                   VOX_CAPTURE_AUDIT_PATH=str(audit_path), VOX_CAPTURE_DOCUMENT_ONLY="0",
                   SCREENSHOT_SETTLE_SECONDS=str(getattr(args, "settle_seconds", 2.0)))
        for name in ("VOX_PROFILE_INSTRUCTIONS", "LADYBIRD_DEBUG_TIMING", "GC_PRINT_STATS",
                     "VOX_CAPTURE_AUDIT_CONFIG"):
            env.pop(name, None)
        config = getattr(args, "capture_audit_config", None)
        if config is not None:
            env["VOX_CAPTURE_AUDIT_CONFIG"] = str(config)
        if args.counter_backend == "linux-perf":
            report = run_perf_command(command, cwd=REPO, env=env, log_path=log_path,
                                      timeout=args.timeout)
        else:
            runner = run_cachegrind_command if args.counter_backend == "cachegrind" else run_callgrind_command
            report = runner(command, cwd=REPO, env=env, log_path=log_path,
                            timeout=args.timeout, prefix=prefix,
                            valgrind=getattr(args, "valgrind", "valgrind"))
    if not window.is_file() or not audit_path.is_file():
        raise RuntimeError(f"Linux capture omitted its screenshot or document audit; see {log_path}")
    audit = json.loads(audit_path.read_text())
    validate_capture_audit(audit, args)
    crop_document_viewport(window, screenshot, args.width, args.height)
    validate_linux_renderer_log(log_path)
    pixels = validate_screenshot(screenshot, getattr(args, "expected_png", None), args.width, args.height)
    report.update(engine="vox", binary=str(binary), url=args.url, viewport=[args.width, args.height],
                  endpoint="program exec through process exit after native document capture",
                  endpoint_note="includes startup, window work, readiness, settle, PNG capture, and teardown; excludes external X server",
                  screenshot=str(screenshot), native_window_screenshot=str(window),
                  document_audit=audit, screenshot_validation=pixels,
                  settle_seconds=getattr(args, "settle_seconds", 2.0),
                  profile_policy="fresh private profile for each observation",
                  cache_policy="fresh copy of supplied cache" if cache_dir is not None else "fresh empty cache",
                  rendering_environment={name: env.get(name) for name in (
                      "GC_MARKERS", "JSC_useJIT", "LIBGL_ALWAYS_SOFTWARE", "DISPLAY",
                      "LP_NUM_THREADS", "GALLIUM_DRIVER",
                      "MESA_GL_VERSION_OVERRIDE", "LD_LIBRARY_PATH", "VALGRIND_LIB")},
                  native={"phases": [], "scopes": {}, "unavailable": ["Native in-process instruction scopes are not implemented on Linux"]})
    if config is not None:
        report["capture_audit_config_sha256"] = hashlib.sha256(Path(config).read_bytes()).hexdigest()
    return report


def run_vox(args, prefix, api, cache_dir=None):
    if getattr(args, "counter_backend", None) in ("linux-perf", "callgrind", "cachegrind"):
        return run_vox_linux(args, prefix, cache_dir)
    binary = args.binary or REPO / "Build/v/Vox.app/Contents/MacOS/Vox"
    screenshot = Path(str(prefix) + ".png")
    window_screenshot = Path(str(prefix) + ".window.png")
    window_screenshot.unlink(missing_ok=True)
    log_path = Path(str(prefix) + ".log")
    env = native_capture_environment(args, cache_dir)
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
                  native_instruction_markers=getattr(args, 'native_instruction_markers', True),
                  settle_seconds=capture_settle_seconds(args),
                  native=parse_native_counters(log_path.read_text()), screenshot=str(screenshot),
                  native_window_screenshot=str(window_screenshot))
    return report


def run_chrome(args, prefix, api, client_factory=None):
    settle_seconds = capture_settle_seconds(args)
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
                    expression = getattr(args, 'chrome_readiness_expression', None) or expression
                    while True:
                        evaluated = client.call("Runtime.evaluate", {"expression": expression, "returnByValue": True})
                        value = evaluated.get("result", {}).get("value")
                        document = json.loads(value) if value else {}
                        github = urllib.parse.urlparse(args.url).hostname == "github.com" and "/vlang/v" in args.url
                        if (document.get("ready") == "complete" and document.get("textLength", 0) > 0
                                and document.get('captureReady', True) is True
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
                    if settle_seconds:
                        time.sleep(settle_seconds)
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
                                  settle_seconds=settle_seconds,
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
                    finish_chrome_capture(client, process, report, prefix)
            finally:
                if client:
                    client.sock.close()
                stop_process(process)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", choices=["vox", "chrome"], default="vox")
    parser.add_argument("--binary", type=Path)
    parser.add_argument("--counter-backend", choices=["auto", "macos", "linux-perf", "callgrind", "cachegrind"], default="auto",
                        help="auto selects the native hardware backend; Callgrind and Cachegrind Ir are separate explicit software metrics")
    parser.add_argument("--valgrind", default="valgrind", help="Valgrind executable for either explicit software backend")
    parser.add_argument("--settle-seconds", type=float, default=2.0,
                        help="Seconds to settle after document readiness before native/CDP capture")
    parser.add_argument("--expect-title", help="Linux only: require this exact document title")
    parser.add_argument("--capture-audit-config", type=Path,
                        help="Linux only: additional native capture audit selectors")
    parser.add_argument("--expected-png", type=Path,
                        help="Linux only: require exact decoded pixels against this reference viewport")
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
    if args.repeat < 1 or args.timeout <= 0 or args.width < 1 or args.height < 1 or args.sample_interval <= 0 or args.settle_seconds < 0:
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
    if args.counter_backend == "auto":
        args.counter_backend = "macos" if platform.system() == "Darwin" else "linux-perf"
    if args.counter_backend != "macos" and (platform.system() != "Linux" or args.engine != "vox"):
        parser.error("linux-perf, callgrind, and cachegrind require Linux and engine vox")
    if args.counter_backend == "macos" and (args.expect_title or args.capture_audit_config or args.expected_png):
        parser.error("capture audit/title/pixel guards currently require a Linux backend")
    for option in ("capture_audit_config", "expected_png"):
        value = getattr(args, option)
        if value is not None:
            if not value.is_file():
                parser.error(f"{option.replace('_', '-')} requires an existing file")
            setattr(args, option, value.resolve())
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
    api = MacCounters() if args.counter_backend == "macos" else None
    runs = []
    for index in range(args.repeat):
        prefix = Path(str(args.output) + f".run-{index + 1}")
        binary = args.binary or (REPO / ("Build/linux/vox" if args.counter_backend != "macos" else "Build/v/Vox.app/Contents/MacOS/Vox") if args.engine == "vox"
                                 else Path("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"))
        binary_before = hashlib.sha256(binary.read_bytes()).hexdigest()
        runtime_before = fingerprint_files(args.runtime_library)
        try:
            with fresh_vox_cache(args.cache_template, args.scratch_dir) as (cache, template_hash):
                result = (run_vox(args, prefix, api, cache) if args.engine == "vox"
                          else run_chrome(args, prefix, api))
                if template_hash is not None:
                    result["cache_template_sha256"] = template_hash
        except Exception as error:
            failure = Path(str(prefix) + ".failure.json")
            if failure.exists():
                failure = Path(str(prefix) + f".failure-{time.time_ns()}.json")
            with failure.open("x") as destination:
                destination.write(json.dumps({
                "valid": False, "counter_backend": args.counter_backend, "error": str(error),
                "binary": str(binary), "binary_sha256": binary_before,
                "url": args.url, "viewport": [args.width, args.height]}, indent=2) + "\n")
            raise
        result["binary_sha256"] = hashlib.sha256(Path(result["binary"]).read_bytes()).hexdigest()
        if result["binary_sha256"] != binary_before:
            raise RuntimeError("Measured executable changed during capture")
        result["runtime_libraries"] = fingerprint_files(args.runtime_library)
        if result["runtime_libraries"] != runtime_before:
            raise RuntimeError("Measured runtime library changed during capture")
        result["measurement_driver_sha256"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        result["counter_module_sha256"] = hashlib.sha256((REPO / "tools/process_instruction_counts.py").read_bytes()).hexdigest()
        if args.counter_backend != "macos":
            result["linux_counter_module_sha256"] = hashlib.sha256((REPO / "tools/linux_instruction_counts.py").read_bytes()).hexdigest()
        result["sample_interval_seconds"] = args.sample_interval
        result["screenshot_sha256"] = hashlib.sha256(Path(result["screenshot"]).read_bytes()).hexdigest()
        Path(str(prefix) + ".json").write_text(json.dumps(result, indent=2) + "\n")
        runs.append(result)
        progress = {"run": index + 1, "engine": args.engine,
                          "instruction_metric": result.get("instruction_metric", "hardware_retired_instructions"),
                          "instructions": result["instructions"],
                          "aggregate_is_lower_bound": result["aggregate_is_lower_bound"],
                          "root_instructions": result["root_instructions"],
                          "root_final_exit_sample": result["root_final_exit_sample"],
                          "root_lifetime_max_phys_footprint": result["root_lifetime_max_phys_footprint"],
                          "missing_final_sample_count": result["missing_final_sample_count"],
                          "native_scopes": result.get("native", {}).get("scopes"),
                          "navigation_to_screenshot_instructions": result.get("navigation_to_screenshot", {}).get("instructions")}
        if args.counter_backend == "macos":
            progress["observed_process_tree_instructions"] = result["instructions"]
        print(json.dumps(progress), flush=True)
    summary = {"machine": platform.machine(), "kernel": platform.release(), "engine": args.engine,
               "counter_backend": args.counter_backend,
               "instruction_metric": runs[0].get("instruction_metric", "hardware_retired_instructions"),
               "aggregate_is_lower_bound": any(r["aggregate_is_lower_bound"] for r in runs),
               "median_instructions": statistics.median(r["instructions"] for r in runs),
               "median_root_instructions": (statistics.median(r["root_instructions"] for r in runs)
                   if all(r["root_instructions"] is not None for r in runs) else None), "runs": runs}
    if args.counter_backend == "macos":
        summary["median_observed_process_tree_instructions"] = summary["median_instructions"]
    Path(str(args.output) + ".json").write_text(json.dumps(summary, indent=2) + "\n")


if __name__ == "__main__":
    main()
