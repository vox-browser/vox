#!/usr/bin/env python3
"""Capture a Brave (Chromium) reference screenshot of a page through CDP.

usage: capture_brave_reference.py --url URL --out OUT.png [--width 1024]
       [--height 768] [--scale 2] [--no-js] [--rects RECTS.json]

The page renders in a fresh headless profile at the requested viewport and
device scale. Focus emulation matches a focused browser window, and the
capture waits for document load and web fonts. --rects writes every element's
client rectangle as JSON for geometry comparisons.
"""
import argparse
import base64
import json
import subprocess
import tempfile
import time
import urllib.request
from pathlib import Path

from measure_browser_instructions import CDP, chrome_debugger_endpoint, stop_process

BRAVE = "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
RECTS = r"""JSON.stringify([...document.querySelectorAll('*')].map((e, i) => {
  const r = e.getBoundingClientRect();
  const name = e.className && e.className.baseVal !== undefined ? e.className.baseVal : e.className;
  return [i, e.tagName, e.id, name, +r.x.toFixed(4), +(r.y + scrollY).toFixed(4),
    +r.width.toFixed(4), +r.height.toFixed(4)];
}))"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--binary", default=BRAVE)
    parser.add_argument("--url", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--width", type=int, default=1024)
    parser.add_argument("--height", type=int, default=768)
    parser.add_argument("--scale", type=float, default=2)
    parser.add_argument("--no-js", action="store_true", help="disable page JavaScript")
    parser.add_argument("--rects", help="write element rectangles as JSON")
    parser.add_argument("--settle", type=float, default=2, help="seconds to wait after load")
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix="brave-reference-") as profile:
        command = [args.binary, "--headless=new", "--no-first-run", "--no-default-browser-check",
                   "--disable-background-networking", "--remote-debugging-port=0",
                   "--hide-scrollbars", "--lang=en-US", f"--user-data-dir={profile}", "about:blank"]
        process = subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                   start_new_session=True)
        try:
            deadline = time.monotonic() + 30
            while (endpoint := chrome_debugger_endpoint(Path(profile) / "DevToolsActivePort")) is None:
                if time.monotonic() > deadline:
                    raise SystemExit("Brave did not open a debugging port")
                time.sleep(0.05)
            port, _ = endpoint
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
            targets = json.load(opener.open(f"http://127.0.0.1:{port}/json/list", timeout=15))
            cdp = CDP(next(t["webSocketDebuggerUrl"] for t in targets if t["type"] == "page"))
            cdp.call("Page.enable")
            cdp.call("Runtime.enable")
            cdp.call("Emulation.setDeviceMetricsOverride", {
                "width": args.width, "height": args.height,
                "deviceScaleFactor": args.scale, "mobile": False})
            if args.no_js:
                cdp.call("Emulation.setScriptExecutionDisabled", {"value": True})
            cdp.call("Emulation.setFocusEmulationEnabled", {"enabled": True})
            cdp.call("Page.navigate", {"url": args.url})
            while True:
                state = cdp.call("Runtime.evaluate", {"expression": "document.readyState",
                                                      "returnByValue": True})
                if state.get("result", {}).get("value") == "complete":
                    break
                time.sleep(0.1)
            cdp.call("Runtime.evaluate", {"expression": "document.fonts.ready.then(() => true)",
                                          "awaitPromise": True})
            time.sleep(args.settle)
            data = cdp.call("Page.captureScreenshot", {"format": "png"})["data"]
            Path(args.out).write_bytes(base64.b64decode(data))
            if args.rects:
                rects = cdp.call("Runtime.evaluate", {"expression": RECTS, "returnByValue": True})
                Path(args.rects).write_text(rects["result"]["value"])
            try:
                cdp.call("Browser.close")
            except Exception:
                pass
        finally:
            stop_process(process)


if __name__ == "__main__":
    main()
