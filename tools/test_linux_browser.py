#!/usr/bin/env python3
"""Exercise the Linux executable, local/network documents, scripts and X11 paint."""

import functools
import http.server
import os
import shutil
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

    def do_GET(self):
        if self.path == "/keyboard":
            body = b"<!doctype html><title>Vox keyboard navigation</title><h1>Address entry works</h1>"
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
    environment = kwargs.pop("env", dict(os.environ))
    bypass = "127.0.0.1,localhost,::1," + environment.get("NO_PROXY", environment.get("no_proxy", ""))
    environment.update(NO_PROXY=bypass, no_proxy=bypass)
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=120, env=environment, **kwargs)
    if result.returncode:
        raise RuntimeError(f"{command!r} exited {result.returncode}:\n{result.stdout}")
    return result.stdout


def check_rendered_pixels(data):
    width, height, depth, kind = struct.unpack(">IIBB", data[16:26])
    assert depth == 8 and kind in (2, 6)
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
    green = white = 0
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
        for x in range(0, stride, channels):
            green += row[x:x + 3] == b"\x2c\xa0\x5a"
            white += row[x:x + 3] == b"\xff\xff\xff"
        previous = row
    assert green > width * height * 0.6, f"Missing page background: {green} pixels"
    assert white > 200, f"Missing retained text: {white} pixels"


def check_keyboard_navigation(binary, page, address):
    with tempfile.TemporaryFile(mode="w+") as log:
        browser = subprocess.Popen([binary, page], stdout=log, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 20
            window = ""
            while time.monotonic() < deadline:
                if browser.poll() is not None:
                    log.seek(0)
                    raise RuntimeError(log.read())
                result = subprocess.run(["xdotool", "search", "--onlyvisible", "--name", "Vox Linux smoke"],
                                        text=True, stdout=subprocess.PIPE)
                if result.returncode == 0:
                    window = result.stdout.splitlines()[0]
                    break
                time.sleep(0.1)
            assert window, "The Linux browser window did not appear"
            run(["xdotool", "windowfocus", "--sync", window])
            run(["xdotool", "key", "--clearmodifiers", "ctrl+l"])
            run(["xdotool", "type", "--clearmodifiers", "--delay", "1", address])
            run(["xdotool", "key", "Return"])
            while time.monotonic() < deadline:
                title = run(["xdotool", "getwindowname", window])
                if "Vox keyboard navigation" in title:
                    return
                time.sleep(0.1)
            log.seek(0)
            if shutil.which("scrot"):
                subprocess.run(["scrot", str(Path(__file__).resolve().parent.parent / "Build/linux/keyboard-failure.png")])
            raise AssertionError("Ctrl+L / Enter navigation failed:\n" + log.read())
        finally:
            browser.terminate()
            browser.wait(timeout=5)


def check_https_navigation(binary, directory):
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
                     env=dict(os.environ, SSL_CERT_FILE=str(certificate)))
        assert "Linux JavaScript rendered" in output, output
        untrusted = dict(os.environ)
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
    if len(sys.argv) > 1 and sys.argv[1] == "--keyboard":
        check_keyboard_navigation(*sys.argv[2:])
        return
    repo = Path(__file__).resolve().parent.parent
    binary = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else repo / "Build/linux/vox"
    output = run([str(binary), "--headless-smoke"])
    assert "javascript DOM mutation: passed" in output, output
    assert "ordinary element wheel listeners: passed" in output, output
    print("PASS: headless JavaScript, DOM, events and wheel scrolling")
    with tempfile.TemporaryDirectory(prefix="vox-linux-") as temporary:
        page = Path(temporary) / "linux.html"
        page.write_text('''<!doctype html><title>Vox Linux smoke</title>
<style>body{margin:0;background:#2ca05a;color:white}h1{font:32px sans-serif;padding:24px}</style>
<h1 id="result">script has not run</h1>
<script>document.getElementById('result').textContent='Linux JavaScript rendered';</script>''')
        output = run([str(binary), "--headless=layout-tree", str(page)])
        assert "Linux JavaScript rendered" in output, output
        print("PASS: local HTML and scripted layout")
        check_https_navigation(binary, temporary)
        print("PASS: HTTPS navigation and certificate verification")
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0),
            functools.partial(Handler, directory=temporary))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            address = f"http://127.0.0.1:{server.server_port}/redirect"
            output = run([str(binary), "--enable-javascript", "--headless=layout-tree", address])
            assert "Linux JavaScript rendered" in output, output
            print("PASS: HTTP navigation, redirect and JavaScript")
            screenshot = repo / "Build/linux/smoke.png"
            screenshot.unlink(missing_ok=True)
            run(["xvfb-run", "-a", "-s", "-screen 0 1024x768x24", str(binary),
                 "--enable-javascript", "--window-width=800", "--window-height=600",
                 "--screenshot-viewport-height=600", f"--screenshot={screenshot}", address],
                env=dict(os.environ, LIBGL_ALWAYS_SOFTWARE="1", SCREENSHOT_SETTLE_SECONDS="0.5"))
            data = screenshot.read_bytes()
            assert data[:8] == b"\x89PNG\r\n\x1a\n" and len(data) > 1000
            assert struct.unpack(">II", data[16:24]) == (800, 600)
            check_rendered_pixels(data)
            print(f"PASS: X11 window and 800x600 rendered screenshot ({screenshot})")
            run(["xvfb-run", "-a", sys.executable, str(Path(__file__).resolve()),
                 "--keyboard", str(binary), str(page),
                 f"http://127.0.0.1:{server.server_port}/keyboard"],
                env=dict(os.environ, LIBGL_ALWAYS_SOFTWARE="1"))
            print("PASS: X11 Ctrl+L, address typing and Enter navigation")
        finally:
            server.shutdown()
            server.server_close()
            thread.join()


if __name__ == "__main__":
    main()
