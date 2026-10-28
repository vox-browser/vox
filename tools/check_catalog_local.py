#!/usr/bin/env python3
"""Compare the same offline catalog file in fresh native Vox and Brave processes.

Run through run_memory_bounded.py --limit-gib 3. No proxy or web server is used.
The supplied process-local network guard denies Vox remote DNS/connect/connectx;
Brave's target is offline, with HTTP(S) blocked and request attempts recorded.
"""

import argparse
import base64
import json
from pathlib import Path
import subprocess
import tempfile
import time

from PIL import Image

from capture_brave_reference import (BRAVE, launch_command, resize_native_viewport,
                                     scroll_viewport)
from check_catalog_replay import REPO, TITLE, compare_pixels, identity, sha, validate_document
from measure_browser_instructions import CDP, chrome_debugger_endpoint, stop_process
from wikipedia_browser_memory import clean_environment, placement

DOCUMENT = '''({url:location.href,title:document.title,ready:document.readyState,
width:innerWidth,height:innerHeight,scale:devicePixelRatio,scroll_x:scrollX,scroll_y:scrollY,
scroll_height:document.documentElement.scrollHeight,
board_title_y:document.querySelector('.boardTitle').getBoundingClientRect().y,
threads:document.querySelectorAll('.thread').length,
thumbnails:[...document.querySelectorAll('.thumb')].map(i=>({complete:i.complete,width:i.naturalWidth}))})'''


class OfflineCDP(CDP):
    def __init__(self, url):
        self.remote_requests = []
        super().__init__(url)

    def receive(self):
        response = super().receive()
        if response.get('method') == 'Network.requestWillBeSent':
            url = response['params']['request']['url']
            if url.startswith(('http:', 'https:')):
                self.remote_requests.append(url)
        return response


def validate_brave_document(metadata, page, width, height):
    if (metadata['url'] != page.as_uri() or metadata['title'] != TITLE or
        metadata['ready'] != 'complete' or metadata['threads'] != 201 or
        (metadata['width'], metadata['height'], metadata['scale']) != (width, height, 2) or
        len(metadata['thumbnails']) != 201 or
        any(not i['complete'] for i in metadata['thumbnails']) or
        sum(i['width'] > 0 for i in metadata['thumbnails']) != 200):
        raise ValueError('Brave did not load the complete catalog')


def brave_capture(binary, page, output, width, height, scroll, screen):
    row = dict(started=time.time())
    with tempfile.TemporaryDirectory(prefix='brave-', dir=output.parent) as profile:
        command = [*launch_command(str(binary), profile, windowed=True), '--no-proxy-server',
                   '--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE localhost']
        row['command'] = command
        browser = cdp = None
        with output.with_suffix('.log').open('w') as log:
            process = subprocess.Popen(command, env=clean_environment(), stdout=log,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            row['pid'] = process.pid
            try:
                deadline = time.monotonic() + 30
                while (endpoint := chrome_debugger_endpoint(Path(profile) / 'DevToolsActivePort')) is None:
                    if process.poll() is not None or time.monotonic() > deadline:
                        raise RuntimeError('Brave did not start')
                    time.sleep(.05)
                port, browser_path = endpoint
                browser = CDP(f'ws://127.0.0.1:{port}{browser_path}')
                row['version'] = browser.call('Browser.getVersion')
                target = browser.call('Target.createTarget', dict(url='about:blank', newWindow=True,
                                      background=True, left=screen['left'], top=screen['top'],
                                      width=width + 80, height=height + 140))['targetId']
                cdp = OfflineCDP(f'ws://127.0.0.1:{port}/devtools/page/{target}')
                for method in ['Page.enable', 'Runtime.enable', 'Network.enable']:
                    cdp.call(method)
                cdp.call('Network.setBlockedURLs', dict(urls=['http://*', 'https://*']))
                cdp.call('Network.emulateNetworkConditions', dict(offline=True, latency=0,
                         downloadThroughput=0, uploadThroughput=0))
                resize_native_viewport(browser, cdp, target, width, height, 2)
                cdp.call('Emulation.setFocusEmulationEnabled', dict(enabled=True))
                navigation = cdp.call('Page.navigate', dict(url=page.as_uri()))
                if navigation.get('errorText'):
                    raise RuntimeError(str(navigation))
                deadline = time.monotonic() + 40
                while cdp.call('Runtime.evaluate', dict(expression='document.readyState',
                                      returnByValue=True))['result'].get('value') != 'complete':
                    if time.monotonic() > deadline:
                        raise RuntimeError('Brave document did not complete')
                    time.sleep(.1)
                cdp.call('Runtime.evaluate', dict(expression='document.fonts.ready', awaitPromise=True))
                time.sleep(2)
                scroll_viewport(cdp, scroll)
                if scroll:
                    time.sleep(2)
                output.write_bytes(base64.b64decode(cdp.call('Page.captureScreenshot',
                                                             dict(format='png'))['data']))
                row['document'] = cdp.call('Runtime.evaluate', dict(expression=DOCUMENT,
                                                  returnByValue=True))['result']['value']
                row['remote_requests'] = cdp.remote_requests
                if row['remote_requests']:
                    raise ValueError('Offline document attempted remote requests')
                browser.call('Browser.close')
                process.wait(timeout=10)
                if process.returncode:
                    raise RuntimeError('Brave capture exited unsuccessfully')
            finally:
                for client in [cdp, browser]:
                    if client:
                        client.sock.close()
                stop_process(process)
                row.update(exit_code=process.returncode, finished=time.time())
                output.with_suffix('.json').write_text(json.dumps(row, indent=2) + '\n')
    return row


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--page', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--network-deny', type=Path, required=True)
    parser.add_argument('--binary', type=Path, default=REPO / 'Build/v/Vox.app/Contents/MacOS/Vox')
    parser.add_argument('--brave', type=Path, default=Path(BRAVE))
    parser.add_argument('--full', action='store_true', help='cover every document pixel, plus two widths')
    parser.add_argument('--settle', type=float, default=2, help='Vox settle seconds for embedded static content')
    args = parser.parse_args()
    if args.settle < 2:
        parser.error('--settle must be at least 2 seconds')
    page, output, binary, brave, guard = [p.resolve() for p in
                                      [args.page, args.output, args.binary, args.brave, args.network_deny]]
    output.mkdir(parents=True, exist_ok=False)
    framework = brave.parent.parent / 'Frameworks/Brave Browser Framework.framework/Brave Browser Framework'
    drivers = [Path(__file__), *[REPO / 'tools' / name for name in
               ['capture_brave_reference.py', 'check_catalog_replay.py',
                'measure_browser_instructions.py', 'wikipedia_browser_memory.py']]]
    report = dict(started=time.time(), page=str(page), page_sha256=sha(page),
                  binary_identity=identity(binary), brave_identity={str(p): sha(p) for p in [brave, framework]},
                  driver_identity={str(p.resolve()): sha(p) for p in drivers},
                  network_guard=str(guard), network_guard_sha256=sha(guard), rows=[], passed=False,
                  vox_settle_seconds=args.settle,
                  networking='No proxy/server; private empty profiles; Vox remote socket/DNS denial; Brave target offline.')

    def save():
        (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')

    config = output / 'audit-config.json'
    config.write_text(json.dumps(dict(selectors=[dict(name=s, selector=s, limit=n) for s, n in
                            [('html', 1), ('.boardTitle', 1), ('.thread', 1), ('.thumb', 8)]])))
    save()
    try:
        screen = placement()
        if screen['scale'] != 2:
            raise ValueError('Native scale 2 required')
        report['screen'] = screen
        cases = [(1024, 768, 0)]
        for width, height, scroll in cases:
            name = f'{width}x{height}-{scroll}'
            row = dict(name=name, started=time.time())
            report['rows'].append(row)
            save()
            reference = output / (name + '-brave.png')
            row['brave'] = brave_capture(brave, page, reference, width, height, scroll, screen)
            metadata = row['brave']['document']
            validate_brave_document(metadata, page, width, height)
            window, actual = output / (name + '-window.png'), output / (name + '-vox.png')
            audit = output / (name + '-audit.json')
            with tempfile.TemporaryDirectory(prefix='vox-', dir=output) as profile:
                env = clean_environment()
                env.update(VOX_PROXY='', VOX_PROFILE_DIR=profile,
                           DYLD_INSERT_LIBRARIES=str(guard), LADYBIRD_SCREENSHOT_SCALE='2',
                           VOX_SCREENSHOT_NATIVE_LAYOUT='1', LADYBIRD_SCREENSHOT_DELAY_SECONDS=str(args.settle),
                           VOX_CAPTURE_AUDIT_PATH=str(audit), VOX_CAPTURE_AUDIT_CONFIG=str(config))
                command = [str(binary), '--window-width', str(width), '--window-height', str(height + 84),
                           '--screenshot-scroll-y', str(scroll), '--screenshot', str(window), page.as_uri()]
                row['vox'] = dict(command=command, started=time.time())
                with (output / (name + '-vox.log')).open('w') as log:
                    process = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT)
                    row['vox']['pid'] = process.pid
                    try:
                        process.wait(timeout=70)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
                        raise RuntimeError('Vox capture timed out')
                    finally:
                        row['vox'].update(exit_code=process.returncode, finished=time.time())
                if process.returncode:
                    raise RuntimeError('Vox capture failed')
            validate_document(json.loads(audit.read_text()), metadata)
            with Image.open(window) as image:
                if image.size != (width * 2, (height + 84) * 2):
                    raise ValueError('Unexpected native window dimensions')
                image.crop((0, 120, width * 2, (height + 60) * 2)).save(actual)
            row.update(compare_pixels(reference, actual, output / (name + '-diff.png')))
            row.update(reference_sha256=sha(reference), actual_sha256=sha(actual), finished=time.time())
            print(f"{name}: {row['differing_pixels']} / {row['total_pixels']} pixels differ", flush=True)
            if len(cases) == 1:
                bottom = metadata['scroll_height'] - height
                offsets = (list(range(height, bottom, height)) + [bottom] if args.full else
                           [int(bottom / 2), bottom])
                cases.extend((width, height, y) for y in offsets)
                cases.extend([(800, 600, 0), (1280, 768, 0)])
            save()
        report['passed'] = all(r['differing_pixels'] == 0 for r in report['rows'])
    except Exception as error:
        report['error'] = str(error)
    finally:
        save()
        report['identities_unchanged'] = (identity(binary) == report['binary_identity'] and
            {str(p): sha(p) for p in [brave, framework]} == report['brave_identity'] and
            {str(p.resolve()): sha(p) for p in drivers} == report['driver_identity'] and
            sha(guard) == report['network_guard_sha256'] and sha(page) == report['page_sha256'])
        report['passed'] = report['passed'] and report['identities_unchanged']
        report['finished'] = time.time()
        save()
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
