#!/usr/bin/env python3
"""Capture a Brave (Chromium) reference screenshot of a page through CDP.

usage: capture_brave_reference.py --url URL --out OUT.png [--width 1024]
       [--height 768] [--scale 2] [--no-js] [--rects RECTS.json]

The page renders in a fresh headless profile at the requested viewport and
device scale. Focus emulation matches a focused browser window, and the
capture waits for document load and web fonts. --rects writes every element's
client rectangle as JSON for geometry comparisons. --proxy-server and
--cookie-file reuse an explicitly imported session in the isolated profile.
"""
import argparse
import base64
import json
import subprocess
import tempfile
import time
import urllib.request
from urllib.parse import urlsplit
from pathlib import Path

from measure_browser_instructions import CDP, chrome_debugger_endpoint, stop_process

BRAVE = "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
RECTS = r"""JSON.stringify([...document.querySelectorAll('*')].map((e, i) => {
  const r = e.getBoundingClientRect();
  const name = e.className && e.className.baseVal !== undefined ? e.className.baseVal : e.className;
  return [i, e.tagName, e.id, name, +r.x.toFixed(4), +(r.y + scrollY).toFixed(4),
    +r.width.toFixed(4), +r.height.toFixed(4)];
}))"""


def imported_cookies(path):
    """Load a private Netscape jar without printing or copying its values."""
    cookies = []
    for line in path.read_text().splitlines():
        http_only = line.startswith('#HttpOnly_')
        if http_only:
            line = line[len('#HttpOnly_'):]
        elif line.startswith('#') or not line:
            continue
        fields = line.split('\t')
        if len(fields) != 7:
            raise ValueError('Invalid Netscape cookie row')
        domain, subdomains, cookie_path, secure, expires, name, value = fields
        if subdomains not in ('TRUE', 'FALSE') or secure not in ('TRUE', 'FALSE'):
            raise ValueError('Invalid Netscape cookie attributes')
        expires = int(expires) if expires else 0
        if expires < 0:
            raise ValueError('Invalid Netscape cookie expiry')
        if expires and expires <= time.time():
            continue
        if not domain or not cookie_path.startswith('/') or not name:
            raise ValueError('Invalid Netscape cookie scope or name')
        domain = ('.' if subdomains == 'TRUE' else '') + domain.lstrip('.')
        entry = dict(name=name, value=value, domain=domain,
                     path=cookie_path, secure=secure == 'TRUE', httpOnly=http_only)
        if expires:
            entry['expires'] = expires
        cookies.append(entry)
    return cookies


def launch_command(binary, profile, proxy_server=None):
    command = [binary, "--headless=new", "--no-first-run", "--no-default-browser-check",
               "--disable-background-networking", "--disable-sync", "--remote-debugging-port=0",
               "--hide-scrollbars", "--lang=en-US", f"--user-data-dir={profile}"]
    if proxy_server:
        # Chromium's SOCKS5 implementation resolves hostnames at the proxy.
        if proxy_server.startswith('socks5h://'):
            proxy_server = 'socks5://' + proxy_server[len('socks5h://'):]
        command += [f'--proxy-server={proxy_server}']
        if proxy_server.startswith('socks5://'):
            host = urlsplit(proxy_server).hostname
            if not host or any(char in host for char in ',* \t\r\n'):
                raise ValueError('Invalid SOCKS5 proxy hostname')
            command += [f'--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE localhost, EXCLUDE {host}']
    return command + ['about:blank']


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
    parser.add_argument("--proxy-server", help="HTTP or SOCKS5 proxy for this isolated Brave process")
    parser.add_argument("--cookie-file", type=Path, help="private Netscape cookie jar to import")
    parser.add_argument("--metadata", type=Path, help="write final URL, title, login state and viewport")
    parser.add_argument("--timeout", type=float, default=60, help="navigation watchdog in seconds")
    args = parser.parse_args()
    if args.width <= 0 or args.height <= 0 or args.scale <= 0 or args.timeout <= 0 or args.settle < 0:
        parser.error('viewport, scale and timeout must be positive; settle must be nonnegative')

    with tempfile.TemporaryDirectory(prefix="brave-reference-") as profile:
        command = launch_command(args.binary, profile, args.proxy_server)
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
            if args.cookie_file:
                cdp.call('Network.setCookies', {'cookies': imported_cookies(args.cookie_file)})
            cdp.call("Emulation.setDeviceMetricsOverride", {
                "width": args.width, "height": args.height,
                "deviceScaleFactor": args.scale, "mobile": False})
            if args.no_js:
                cdp.call("Emulation.setScriptExecutionDisabled", {"value": True})
            cdp.call("Emulation.setFocusEmulationEnabled", {"enabled": True})
            navigation = cdp.call("Page.navigate", {"url": args.url})
            deadline = time.monotonic() + args.timeout
            while True:
                state = cdp.call("Runtime.evaluate", {"expression": "document.readyState",
                                                      "returnByValue": True})
                if state.get("result", {}).get("value") == "complete":
                    break
                if time.monotonic() > deadline:
                    raise RuntimeError('Brave navigation did not complete before the watchdog')
                time.sleep(0.1)
            cdp.call("Runtime.evaluate", {"expression": "document.fonts.ready.then(() => true)",
                                          "awaitPromise": True})
            time.sleep(args.settle)
            data = cdp.call("Page.captureScreenshot", {"format": "png"})["data"]
            Path(args.out).write_bytes(base64.b64decode(data))
            if args.metadata:
                metadata = cdp.call('Runtime.evaluate', {
                    'expression': "({url:location.href,title:document.title,logged_in:document.body.classList.contains('loggedin'),width:innerWidth,height:innerHeight,scale:devicePixelRatio})",
                    'returnByValue': True})['result']['value']
                if navigation.get('errorText'):
                    metadata['navigation_error'] = navigation['errorText']
                args.metadata.write_text(json.dumps(metadata, indent=2) + '\n')
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
