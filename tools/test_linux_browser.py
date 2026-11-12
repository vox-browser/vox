#!/usr/bin/env python3
"""Exercise the built Linux browser, including native windows and process tabs."""

import argparse
import ctypes
import ctypes.util
import functools
import hashlib
import http.server
import json
import os
import re
import shutil
import signal
import ssl
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import threading
import time
import zlib


class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def end_headers(self):
        # In particular, the trusted HTTPS load must not satisfy the subsequent
        # untrusted load from disk instead of checking its certificate again.
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_GET(self):
        if self.path == "/keyboard":
            body = b'''<!doctype html><title>Vox keyboard navigation</title>
<style>body{margin:0;background:#394cad;color:white}h1{font:32px sans-serif;padding:24px}</style>
<h1>Address entry works</h1>'''
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif self.path == "/redirect":
            self.send_response(302)
            self.send_header("Location", "/linux.html")
            self.send_header("Content-Length", "0")
            self.end_headers()
        else:
            super().do_GET()


def run(command, **kwargs):
    log_path = kwargs.pop("log_path", None)
    environment = dict(kwargs.pop("env", os.environ))
    bypass = "127.0.0.1,localhost,::1," + environment.get("NO_PROXY", environment.get("no_proxy", ""))
    environment.update(NO_PROXY=bypass, no_proxy=bypass)
    try:
        result = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=kwargs.pop("timeout", 120),
                                env=environment, **kwargs)
    except subprocess.TimeoutExpired as error:
        if log_path is not None:
            output = error.output or b""
            Path(log_path).write_text(output.decode(errors="replace") if isinstance(output, bytes) else output)
        raise
    if log_path is not None:
        Path(log_path).write_text(result.stdout)
    if result.returncode:
        raise RuntimeError(f"{command!r} exited {result.returncode}:\n{result.stdout}")
    return result.stdout


def smoke_environment(directory, inherited=None):
    """Use fresh browser state and keep fixture traffic off ambient proxies."""
    directory = Path(directory)
    environment = dict(os.environ if inherited is None else inherited)
    for name in ("VOX_TAB_GROUP", "VOX_TAB_ID", "VOX_PROXY", "SSL_CERT_FILE", "SSL_CERT_DIR",
                 "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy"):
        environment.pop(name, None)
    for name, subdirectory in (("VOX_PROFILE_DIR", "profile"), ("LADYBIRD_CACHE_DIR", "cache"),
                               ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "xdg-cache"),
                               ("TMPDIR", "tmp")):
        path = directory / subdirectory
        path.mkdir(parents=True, exist_ok=True)
        environment[name] = str(path)
    (directory / "profile/settings.json").write_text(json.dumps({"enabled": False}) + "\n")
    # The update opt-out is outside VOX_PROFILE_DIR. Keep this local without
    # changing the developer's machine preference.
    (directory / "config/vox").mkdir(exist_ok=True)
    (directory / "config/vox/no-update-check").touch()
    environment.update(VOX_COOKIE_FILE="", VOX_TEST_WINDOW="1", VOX_TAB_EXIT_DIAGNOSTICS="1",
                       LIBGL_ALWAYS_SOFTWARE="1",
                       NO_PROXY="127.0.0.1,localhost,::1", no_proxy="127.0.0.1,localhost,::1")
    return environment


def require_tools():
    missing = [name for name in ("xvfb-run", "Xvfb", "xauth", "xdotool", "scrot", "openssl")
               if not shutil.which(name)]
    if missing:
        raise RuntimeError("Missing Linux smoke dependencies: " + ", ".join(missing))


def check_rendered_pixels(data, background=b"\x2c\xa0\x5a", size=None):
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "Missing PNG signature"
    width, height, depth, kind = struct.unpack(">IIBB", data[16:26])
    assert depth == 8 and kind in (2, 6)
    if size is not None:
        assert (width, height) == size, f"Wrong captured size: {(width, height)} != {size}"
    channels = 4 if kind == 6 else 3
    compressed = bytearray()
    offset = 8
    while offset < len(data):
        size = struct.unpack(">I", data[offset:offset + 4])[0]
        if data[offset + 4:offset + 8] == b"IDAT":
            compressed.extend(data[offset + 8:offset + 8 + size])
        offset += size + 12
    raw = zlib.decompress(compressed)
    stride = width * channels
    previous = bytearray(stride)
    colored = white = edge = edge_total = 0
    for y in range(height):
        start = y * (stride + 1)
        filter_type = raw[start]
        row = bytearray(raw[start + 1:start + 1 + stride])
        for x in range(stride):
            a = row[x - channels] if x >= channels else 0
            b = previous[x]
            c = previous[x - channels] if x >= channels else 0
            p = a + b - c
            paeth = min((a, b, c), key=lambda value: abs(p - value))
            predictor = (0, a, b, (a + b) // 2, paeth)[filter_type]
            row[x] = (row[x] + predictor) & 255
        row_colored = row_white = 0
        for x in range(0, stride, channels):
            matches = row[x:x + 3] == background
            colored += matches
            row_colored += matches
            row_white += row[x:x + 3] == b"\xff\xff\xff"
            if x // channels >= width - 80 and height // 3 <= y < height - 80:
                edge += matches
                edge_total += 1
        # White browser chrome must not satisfy the retained document-text
        # check. Count text only on rows dominated by the fixture background.
        if row_colored > width * 0.6:
            white += row_white
        previous = row
    assert colored > width * height * 0.6, f"Missing page background: {colored} pixels"
    assert white > 200, f"Missing retained text: {white} pixels"
    assert edge > edge_total * 0.8, "The right edge was not repainted after resize/switch"


def check_webgl_pixels(data):
    """Find both complete shader canvases, excluding unknown browser chrome."""
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "Missing WebGL PNG"
    width, height, depth, kind = struct.unpack(">IIBB", data[16:26])
    assert depth == 8 and kind in (2, 6), "Unsupported WebGL capture format"
    channels = 4 if kind == 6 else 3
    compressed = bytearray()
    offset = 8
    while offset < len(data):
        size = struct.unpack(">I", data[offset:offset + 4])[0]
        if data[offset + 4:offset + 8] == b"IDAT":
            compressed.extend(data[offset + 8:offset + 8 + size])
        offset += size + 12
    raw = zlib.decompress(compressed)
    stride = width * channels
    previous = bytearray(stride)
    rows = []
    for y in range(height):
        start = y * (stride + 1)
        filter_type = raw[start]
        assert filter_type <= 4
        row = bytearray(raw[start + 1:start + 1 + stride])
        for x in range(stride):
            a = row[x - channels] if x >= channels else 0
            b = previous[x]
            c = previous[x - channels] if x >= channels else 0
            p = a + b - c
            paeth = min((a, b, c), key=lambda value: abs(p - value))
            row[x] = (row[x] + (0, a, b, (a + b) // 2, paeth)[filter_type]) & 255
        rows.append(bytes(row))
        previous = row
    def pixel(rgb):
        return bytes(rgb) + (b"\xff" if channels == 4 else b"")
    top = pixel((255, 0, 0)) * 64 + pixel((0, 255, 0)) * 64
    bottom = pixel((0, 0, 255)) * 64 + pixel((255, 255, 0)) * 64
    for y in range(min(200, height - 63)):
        for x in range(min(8, width - 127)):
            start, end = x * channels, (x + 128) * channels
            if all(rows[y + dy][start:end] == (top if dy < 32 else bottom) for dy in range(64)):
                return
    raise AssertionError("Missing or incorrect WebGL1/WebGL2 shader presentation pixels")


def check_webgl_browser(binary, artifacts, temporary):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native/webgl-smoke.html"
    pins = {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in (binary, fixture, Path(__file__).resolve())}
    environment = smoke_environment(Path(temporary) / "webgl")
    audit = artifacts / "webgl-audit.json"
    screenshot = artifacts / "webgl.png"
    environment['VOX_CAPTURE_AUDIT_PATH'] = str(audit)
    screenshot.unlink(missing_ok=True)
    run(["xvfb-run", "-a", "-s", "-screen 0 1024x768x24", str(binary),
         "--enable-javascript", "--window-width=800", "--window-height=600",
         "--screenshot-viewport-height=600", f"--screenshot={screenshot}", str(fixture)],
        env=environment, timeout=90, log_path=artifacts / "webgl.log")
    result = json.loads(audit.read_text())
    assert result['title'] == 'WebGL GPU smoke PASS', result
    assert result['ready'] == 'complete' and result['native_reported_error_count'] == 0
    diagnostic = next((line for line in result['javascript_diagnostics'] if line.startswith('WEBGL_GPU_SMOKE_PASS ')), '')
    assert diagnostic, "Author WebGL script did not execute"
    renderers = json.loads(diagnostic.split(' ', 1)[1])
    assert len(renderers) == 2 and all(renderer and 'ANGLE' not in renderer for renderer in renderers), renderers
    check_webgl_pixels(screenshot.read_bytes())
    assert all(hashlib.sha256(Path(name).read_bytes()).hexdigest() == value
               for name, value in pins.items()), "WebGL inputs changed during capture"
    (artifacts / "webgl-result.json").write_text(json.dumps(
        dict(passed=True, pins=pins, renderers=renderers, audit=result), indent=2) + "\n")
    print('PASS: native GLES WebGL1/WebGL2 shaders, readback and canvas presentation', flush=True)


def wait_for(description, predicate, browser=None, timeout=20):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if browser is not None and browser.poll() is not None:
            raise AssertionError(f"Browser exited {browser.returncode} while waiting for {description}")
        result = predicate()
        if result:
            return result
        time.sleep(0.1)
    raise AssertionError(f"Timed out waiting for {description}")


def process_group_alive(pid):
    try:
        os.killpg(pid, 0)
        return True
    except ProcessLookupError:
        return False


def successful_tab_exit(log, pid):
    """Require the native reaper's actual waitpid status for this one child."""
    statuses = []
    for line in log.splitlines():
        match = re.fullmatch(r"VOX_TAB_EXIT pid=(\d+) code=(-?\d+) signal=(\d+)", line)
        if match and int(match[1]) == pid:
            statuses.append((int(match[2]), int(match[3])))
    if not statuses:
        return False
    assert len(statuses) == 1, f"Duplicate exit diagnostics for tab process {pid}: {statuses}"
    code, signum = statuses[0]
    assert (code, signum) == (0, 0), f"Tab process {pid} failed: code={code} signal={signum}"
    return True


def terminate_process_group(browser):
    """Failure cleanup only; successful tests first prove a normal exit."""
    try:
        os.killpg(browser.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        browser.wait(timeout=5)
    except subprocess.TimeoutExpired:
        pass
    if process_group_alive(browser.pid):
        try:
            os.killpg(browser.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        browser.wait(timeout=5)


def visible_window(title, pid=None):
    command = ["xdotool", "search", "--onlyvisible", "--all"]
    if pid is not None:
        command += ["--pid", str(pid)]
    command += ["--name", title]
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, timeout=5)
    if result.returncode not in (0, 1):
        raise RuntimeError(f"X11 window search failed: {result.stderr}")
    return result.stdout.splitlines()[0] if result.returncode == 0 and result.stdout.strip() else None


def close_native_window(window):
    """Deliver the window-manager close protocol without requiring a WM."""
    class ClientMessage(ctypes.Structure):
        _fields_ = [("type", ctypes.c_int), ("serial", ctypes.c_ulong),
                    ("send_event", ctypes.c_int), ("display", ctypes.c_void_p),
                    ("window", ctypes.c_ulong), ("message_type", ctypes.c_ulong),
                    ("format", ctypes.c_int), ("data", ctypes.c_long * 5)]

    class Event(ctypes.Union):
        _fields_ = [("client", ClientMessage), ("padding", ctypes.c_long * 24)]

    library = ctypes.util.find_library("X11")
    if library is None:
        raise RuntimeError("libX11 is required for the native close check")
    x11 = ctypes.CDLL(library)
    x11.XOpenDisplay.argtypes, x11.XOpenDisplay.restype = [ctypes.c_char_p], ctypes.c_void_p
    x11.XInternAtom.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
    x11.XInternAtom.restype = ctypes.c_ulong
    x11.XSendEvent.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int,
                              ctypes.c_long, ctypes.POINTER(Event)]
    x11.XSendEvent.restype = ctypes.c_int
    x11.XFlush.argtypes = x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    display = x11.XOpenDisplay(None)
    if not display:
        raise RuntimeError("Cannot open the X11 display for the native close check")
    try:
        event = Event()
        event.client.type = 33  # ClientMessage
        event.client.display = display
        event.client.window = int(window)
        event.client.message_type = x11.XInternAtom(display, b"WM_PROTOCOLS", False)
        event.client.format = 32
        event.client.data[0] = x11.XInternAtom(display, b"WM_DELETE_WINDOW", False)
        if not x11.XSendEvent(display, int(window), False, 0, ctypes.byref(event)):
            raise RuntimeError("WM_DELETE_WINDOW could not be delivered")
        x11.XFlush(display)
    finally:
        x11.XCloseDisplay(display)


def check_window_lifecycle(binary, page, address, output):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    log_path = output / "window.log"
    with log_path.open("w") as log:
        browser = subprocess.Popen([binary, "--enable-javascript", "--window-width=800",
                                    "--window-height=600", page], stdout=log,
                                   stderr=subprocess.STDOUT, start_new_session=True)

        def wait(description, predicate):
            return wait_for(description, predicate, browser)

        def key(window, shortcut):
            run(["xdotool", "windowfocus", "--sync", window], timeout=5)
            run(["xdotool", "key", "--clearmodifiers", shortcut], timeout=5)

        def navigate(window, destination):
            key(window, "ctrl+l")
            run(["xdotool", "type", "--clearmodifiers", "--delay", "1", destination], timeout=10)
            key(window, "Return")

        def open_process_tab(window, description):
            key(window, "ctrl+t")
            child = wait(description, lambda: visible_window("^New Tab"))
            child_pid = int(run(["xdotool", "getwindowpid", child], timeout=5).strip())
            assert child_pid != browser.pid, "New tab did not start an independent process"
            assert os.getpgid(child_pid) == browser.pid, "New-tab window belongs to another launch"
            wait("original tab hidden", lambda: not visible_window("Vox keyboard navigation", browser.pid))
            return child, child_pid

        def painted(window, label, background, size):
            # --screenshot exits and disables process tabs. Read back this live
            # X11 window to cover native presentation after resize and switch.
            run(["xdotool", "windowfocus", "--sync", window], timeout=5)
            screenshot = output / f"{label}.png"
            last_error = ""

            def capture():
                nonlocal last_error
                run(["scrot", "--focused", "--overwrite", str(screenshot)], timeout=5)
                try:
                    check_rendered_pixels(screenshot.read_bytes(), background, size)
                    return True
                except AssertionError as error:
                    last_error = str(error)
                    return False

            try:
                wait(f"{label} pixels", capture)
            except AssertionError as error:
                raise AssertionError(f"{error}: {last_error}") from error

        try:
            original = wait("initial X11 window", lambda: visible_window("Vox Linux smoke", browser.pid))
            painted(original, "startup", b"\x2c\xa0\x5a", (800, 600))
            navigate(original, address)
            wait("Ctrl+L / Enter replacement", lambda: visible_window("Vox keyboard navigation", browser.pid))
            painted(original, "navigation", b"\x39\x4c\xad", (800, 600))
            print("PASS: X11 startup, native paint and keyboard document replacement", flush=True)

            run(["xdotool", "windowsize", "--sync", original, "960", "720"], timeout=5)
            painted(original, "resize", b"\x39\x4c\xad", (960, 720))
            print("PASS: X11 resize and redraw at 960x720", flush=True)

            child, child_pid = open_process_tab(original, "new process tab")
            navigate(child, page)
            wait("child document", lambda: visible_window("Vox Linux smoke", child_pid))
            painted(child, "child", b"\x2c\xa0\x5a", (960, 720))

            key(child, "ctrl+shift+Tab")
            wait("switch to original", lambda: visible_window("Vox keyboard navigation", browser.pid) == original)
            wait("child tab hidden", lambda: not visible_window("Vox Linux smoke", child_pid))
            painted(original, "switch-original", b"\x39\x4c\xad", (960, 720))
            key(original, "ctrl+Tab")
            wait("switch to child", lambda: visible_window("Vox Linux smoke", child_pid) == child)
            painted(child, "switch-child", b"\x2c\xa0\x5a", (960, 720))
            key(child, "ctrl+w")
            wait("child process reaped", lambda: not Path(f"/proc/{child_pid}").exists())
            # waitpid can remove /proc/PID before the reaper writes its status.
            # Open independently: seeking the shared stdout descriptor would
            # also move the browser writer's offset.
            wait("successful child exit status", lambda: successful_tab_exit(log_path.read_text(errors="replace"), child_pid))
            wait("original restored after close", lambda: visible_window("Vox keyboard navigation", browser.pid) == original)
            painted(original, "close-tab", b"\x39\x4c\xad", (960, 720))
            print("PASS: process-tab startup, switching, retained paint and child retirement", flush=True)

            # Keep another process alive when closing the native window, so
            # this also checks the group's shutdown path with a hidden sibling.
            sibling, sibling_pid = open_process_tab(original, "second process tab")
            key(sibling, "ctrl+shift+Tab")
            wait("original selected before group close", lambda: visible_window("Vox keyboard navigation", browser.pid) == original)
            wait("sibling hidden before group close", lambda: not visible_window("^New Tab", sibling_pid))
            assert Path(f"/proc/{sibling_pid}").exists(), "Sibling exited before the group-close check"
            # Forced termination in finally must never count as a passing close.
            close_native_window(original)
            assert browser.wait(timeout=20) == 0, "Browser did not exit normally"
            wait_for("sibling process retired by native close", lambda: not Path(f"/proc/{sibling_pid}").exists(), timeout=10)
            wait_for("all browser processes retired", lambda: not process_group_alive(browser.pid), timeout=5)
            assert not visible_window("Vox keyboard navigation", browser.pid), "Closed window remains visible"
            assert successful_tab_exit(log_path.read_text(errors="replace"), child_pid)
            print("PASS: native close and complete process-group retirement", flush=True)
        except BaseException:
            print(log_path.read_text(errors="replace"), file=sys.stderr)
            raise
        finally:
            terminate_process_group(browser)


def check_https_navigation(binary, directory, environment):
    certificate = Path(directory) / "certificate.pem"
    key = Path(directory) / "key.pem"
    run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
         "-subj", "/CN=localhost", "-addext", "subjectAltName=IP:127.0.0.1",
         "-keyout", str(key), "-out", str(certificate)])
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0),
        functools.partial(Handler, directory=directory))
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(certificate, key)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        address = f"https://127.0.0.1:{server.server_port}/linux.html"
        output = run([str(binary), "--headless=layout-tree", address],
                     env=dict(environment, SSL_CERT_FILE=str(certificate)))
        assert "Linux JavaScript rendered" in output, output
        untrusted = dict(environment)
        untrusted.pop("SSL_CERT_FILE", None)
        output = run([str(binary), "--headless=layout-tree", address], env=untrusted)
        assert "Could not load page" in output, output
    finally:
        server.shutdown()
        server.server_close()
        thread.join()


def main():
    if sys.platform != "linux":
        raise SystemExit("Run this smoke test on Linux")
    if len(sys.argv) > 1 and sys.argv[1] == "--window":
        check_window_lifecycle(*sys.argv[2:])
        return
    repo = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", nargs="?", type=Path, default=repo / "Build/linux/vox")
    parser.add_argument("--output", type=Path, default=repo / "Build/linux/browser-smoke")
    args = parser.parse_args()
    binary = args.binary.resolve()
    artifacts = args.output.resolve()
    require_tools()
    artifacts.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="vox-linux-") as temporary:
        environment = smoke_environment(temporary)
        output = run([str(binary), "--headless-smoke"], env=environment)
        assert "javascript DOM mutation: passed" in output, output
        assert "ordinary element wheel listeners: passed" in output, output
        print("PASS: headless JavaScript, DOM, events and wheel scrolling", flush=True)
        page = Path(temporary) / "linux.html"
        page.write_text('''<!doctype html><title>Vox Linux smoke</title>
<style>body{margin:0;background:#2ca05a;color:white}h1{font:32px sans-serif;padding:24px}</style>
<h1 id="result">script has not run</h1>
<script>document.getElementById('result').textContent='Linux JavaScript rendered';</script>''')
        output = run([str(binary), "--headless=layout-tree", str(page)], env=environment)
        assert "Linux JavaScript rendered" in output, output
        print("PASS: local HTML and scripted layout")
        check_webgl_browser(binary, artifacts, temporary)
        check_https_navigation(binary, temporary, environment)
        print("PASS: HTTPS navigation and certificate verification")
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0),
            functools.partial(Handler, directory=temporary))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            address = f"http://127.0.0.1:{server.server_port}/redirect"
            output = run([str(binary), "--enable-javascript", "--headless=layout-tree", address], env=environment)
            assert "Linux JavaScript rendered" in output, output
            print("PASS: HTTP navigation, redirect and JavaScript")
            screenshot = artifacts / "smoke.png"
            screenshot.unlink(missing_ok=True)
            run(["xvfb-run", "-a", "-s", "-screen 0 1024x768x24", str(binary),
                 "--enable-javascript", "--window-width=800", "--window-height=600",
                 "--screenshot-viewport-height=600", f"--screenshot={screenshot}", address],
                env=dict(environment, SCREENSHOT_SETTLE_SECONDS="0.5"))
            data = screenshot.read_bytes()
            assert data[:8] == b"\x89PNG\r\n\x1a\n" and len(data) > 1000
            assert struct.unpack(">II", data[16:24]) == (800, 600)
            check_rendered_pixels(data)
            print(f"PASS: X11 window and 800x600 rendered screenshot ({screenshot})")
            print(run(["xvfb-run", "-a", "-s", "-screen 0 1280x960x24", sys.executable,
                       str(Path(__file__).resolve()), "--window", str(binary), str(page),
                       f"http://127.0.0.1:{server.server_port}/keyboard", str(artifacts)],
                      env=environment, timeout=300, log_path=artifacts / "window-driver.log"), end="")
        finally:
            server.shutdown()
            server.server_close()
            thread.join()


if __name__ == "__main__":
    main()
