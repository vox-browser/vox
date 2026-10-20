#!/usr/bin/env python3
"""Capture a Brave (Chromium) reference screenshot of a page through CDP.

usage: capture_brave_reference.py --url URL --out OUT.png [--width 1024]
       [--height 768] [--scale 2] [--no-js] [--rects RECTS.json]

The page renders in a fresh isolated profile at the requested viewport and
device scale. Focus emulation matches a focused browser window, and the
capture waits for document load and web fonts. --rects writes every element's
client rectangle as JSON for geometry comparisons. --proxy-server and
--cookie-file reuse an explicitly imported session in the isolated profile.
Captures use sRGB. --windowed --native-scale uses the display's real scale
and resizes the window around the requested viewport without emulation.
"""
import argparse
import base64
import json
import math
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
# Serialize the scripted DOM as a static document that every browser renders
# identically: scripts are removed (noscript stays inert because scripting is
# still enabled), the original base URL is installed ahead of all URL-bearing
# head elements, live form state becomes markup, and nested browsing contexts
# become blank frames of the same box so third-party ads cannot vary per load.
FREEZE = r"""(() => {
  const root = document.documentElement.cloneNode(true);
  const live = [...document.documentElement.querySelectorAll('*')];
  const copy = [...root.querySelectorAll('*')];
  copy.forEach((node, i) => {
    const source = live[i];
    if (source instanceof HTMLInputElement) {
      if (source.type === 'checkbox' || source.type === 'radio')
        source.checked ? node.setAttribute('checked', '') : node.removeAttribute('checked');
      else if (source.type !== 'file' && source.type !== 'password')
        node.setAttribute('value', source.value);
    } else if (source instanceof HTMLTextAreaElement) {
      node.textContent = source.value;
    } else if (source instanceof HTMLOptionElement) {
      source.selected ? node.setAttribute('selected', '') : node.removeAttribute('selected');
    }
  });
  root.querySelectorAll('script, link[rel~="modulepreload"], link[rel~="preload"][as="script"], base')
    .forEach(node => node.remove());
  root.querySelectorAll('iframe, frame').forEach(node => {
    node.removeAttribute('srcdoc');
    node.setAttribute('src', 'about:blank');
  });
  const head = root.querySelector('head');
  const base = document.createElement('base');
  base.setAttribute('href', document.baseURI);
  const charset = head.querySelector('meta[charset]');
  charset ? charset.after(base) : head.prepend(base);
  const type = document.doctype;
  const doctype = !type ? '' : '<!DOCTYPE ' + type.name +
    (type.publicId ? ' PUBLIC "' + type.publicId + '"' : '') +
    (type.systemId ? (type.publicId ? '' : ' SYSTEM') + ' "' + type.systemId + '"' : '') + '>';
  return doctype + root.outerHTML;
})()"""


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


def launch_command(binary, profile, proxy_server=None, windowed=False):
    command = [binary, "--no-first-run", "--no-default-browser-check",
               "--disable-background-networking", "--disable-sync", "--remote-debugging-port=0",
               "--hide-scrollbars", "--force-color-profile=srgb", "--lang=en-US",
               f"--user-data-dir={profile}"]
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
    if windowed:
        return command + ['--no-startup-window']
    return command + ['--headless=new', 'about:blank']


def window_position(value):
    try:
        x, y = map(int, value.split(','))
        return x, y
    except ValueError:
        raise argparse.ArgumentTypeError('window position must be X,Y') from None


def wait_for_page_debugger(opener, port, deadline):
    # The debugging socket can be ready before the initial page target exists.
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise RuntimeError('Brave did not create a page target before the watchdog')
        with opener.open(f'http://127.0.0.1:{port}/json/list', timeout=min(15, remaining)) as response:
            targets = json.load(response)
        page = next((target for target in targets if target['type'] == 'page'), None)
        if page is not None:
            return page['webSocketDebuggerUrl']
        time.sleep(min(.05, remaining))


def resize_native_viewport(browser, cdp, target, width, height, scale):
    """Resize browser chrome around a real viewport without device emulation."""
    window = browser.call('Browser.getWindowForTarget', {'targetId': target})['windowId']
    for _ in range(6):
        viewport = cdp.call('Runtime.evaluate', {
            'expression': '({width:innerWidth,height:innerHeight,scale:devicePixelRatio})',
            'returnByValue': True})['result']['value']
        if viewport['scale'] != scale:
            raise RuntimeError(f"Native display scale is {viewport['scale']}, requested {scale}")
        if viewport['width'] == width and viewport['height'] == height:
            return viewport
        bounds = browser.call('Browser.getWindowBounds', {'windowId': window})['bounds']
        browser.call('Browser.setWindowBounds', {
            'windowId': window, 'bounds': {
                'width': bounds['width'] + width - viewport['width'],
                'height': bounds['height'] + height - viewport['height']}})
        time.sleep(.1)
    raise RuntimeError(f'Brave could not resize its native viewport to {width}x{height}')


def scroll_viewport(cdp, scroll_y):
    position = cdp.call('Runtime.evaluate', {
        'expression': 'new Promise(resolve => {scrollTo({top:' + json.dumps(scroll_y) +
                      ',left:0,behavior:"instant"});requestAnimationFrame(() => '
                      'requestAnimationFrame(() => resolve({x:scrollX,y:scrollY})));})',
        'awaitPromise': True, 'returnByValue': True})['result']['value']
    if position['x'] != 0 or abs(position['y'] - scroll_y) > .001:
        raise RuntimeError(f'Brave could not reach scroll Y {scroll_y}: {position}')
    return position


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
    parser.add_argument("--freeze", type=Path, help="write the scripted DOM as static HTML")
    parser.add_argument("--settle", type=float, default=2, help="seconds to wait after load")
    parser.add_argument("--scroll-y", type=float, default=0, help="document scroll position in CSS pixels")
    parser.add_argument("--proxy-server", help="HTTP or SOCKS5 proxy for this isolated Brave process")
    parser.add_argument("--cookie-file", type=Path, help="private Netscape cookie jar to import")
    parser.add_argument("--metadata", type=Path, help="write final URL, title, login state and viewport")
    parser.add_argument("--timeout", type=float, default=60, help="navigation watchdog in seconds")
    parser.add_argument("--windowed", action="store_true", help="capture a normal background window")
    parser.add_argument("--native-scale", action="store_true",
                        help="resize a window to the viewport using the display's real scale")
    parser.add_argument("--window-position", type=window_position,
                        help="X,Y on the test display away from the pointer; required with --windowed")
    args = parser.parse_args()
    if args.width <= 0 or args.height <= 0 or args.scale <= 0 or args.timeout <= 0 or args.settle < 0:
        parser.error('viewport, scale and timeout must be positive; settle must be nonnegative')
    if args.windowed and args.window_position is None:
        parser.error('--windowed requires --window-position X,Y on the test display')
    if args.native_scale and not args.windowed:
        parser.error('--native-scale requires --windowed')
    if not math.isfinite(args.scroll_y) or args.scroll_y < 0:
        parser.error('--scroll-y must be finite and nonnegative')

    with tempfile.TemporaryDirectory(prefix="brave-reference-") as profile:
        command = launch_command(args.binary, profile, args.proxy_server, args.windowed)
        process = subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                   start_new_session=True)
        browser = cdp = None
        try:
            deadline = time.monotonic() + 30
            while (endpoint := chrome_debugger_endpoint(Path(profile) / "DevToolsActivePort")) is None:
                if time.monotonic() > deadline:
                    raise SystemExit("Brave did not open a debugging port")
                time.sleep(0.05)
            port, browser_path = endpoint
            if args.windowed:
                browser = CDP(f'ws://127.0.0.1:{port}{browser_path}')
                target = browser.call('Target.createTarget', {
                    'url': 'about:blank', 'newWindow': True, 'background': True,
                    'left': args.window_position[0], 'top': args.window_position[1],
                    'width': args.width + 80, 'height': args.height + 140})['targetId']
                cdp = CDP(f'ws://127.0.0.1:{port}/devtools/page/{target}')
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
            if cdp is None:
                cdp = CDP(wait_for_page_debugger(opener, port, deadline))
            cdp.call("Page.enable")
            cdp.call("Runtime.enable")
            if args.cookie_file:
                cdp.call('Network.setCookies', {'cookies': imported_cookies(args.cookie_file)})
            if args.native_scale:
                resize_native_viewport(browser, cdp, target, args.width, args.height, args.scale)
            else:
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
            position = scroll_viewport(cdp, args.scroll_y)
            if args.scroll_y:
                # Newly visible tiles can first show an intermediate decode.
                # Let their final raster settle just like the initial viewport.
                time.sleep(args.settle)
            data = cdp.call("Page.captureScreenshot", {"format": "png"})["data"]
            Path(args.out).write_bytes(base64.b64decode(data))
            if args.metadata:
                metadata = cdp.call('Runtime.evaluate', {
                    'expression': "({url:location.href,title:document.title,logged_in:document.body.classList.contains('loggedin'),width:innerWidth,height:innerHeight,scale:devicePixelRatio})",
                    'returnByValue': True})['result']['value']
                if navigation.get('errorText'):
                    metadata['navigation_error'] = navigation['errorText']
                metadata['native_scale'] = args.native_scale
                metadata['color_profile'] = 'sRGB'
                metadata['scroll_x'] = position['x']
                metadata['scroll_y'] = position['y']
                args.metadata.write_text(json.dumps(metadata, indent=2) + '\n')
            if args.rects:
                rects = cdp.call("Runtime.evaluate", {"expression": RECTS, "returnByValue": True})
                Path(args.rects).write_text(rects["result"]["value"])
            if args.freeze:
                frozen = cdp.call("Runtime.evaluate", {"expression": FREEZE, "returnByValue": True})
                if 'exceptionDetails' in frozen:
                    raise RuntimeError('Brave could not serialize the document')
                args.freeze.write_text(frozen["result"]["value"], encoding='utf-8')
            try:
                cdp.call("Browser.close")
            except Exception:
                pass
        finally:
            if cdp is not None:
                cdp.sock.close()
            if browser is not None:
                browser.sock.close()
            stop_process(process)


if __name__ == "__main__":
    main()
