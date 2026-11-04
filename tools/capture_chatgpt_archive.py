#!/usr/bin/env python3
"""Capture one anonymous ChatGPT homepage navigation through a SOCKS proxy.

Retain original responses, scripts and a separately labelled rendered snapshot.
Never submit a prompt, import a login, retry a navigation, or fetch missing assets.
Run through run_memory_bounded.py; subsequent measurements use disk replay only.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

from capture_brave_reference import FREEZE, launch_command
from forum_news_pixels import brave_identity
from hacker_news_browser_instructions import test_display
from measure_browser_instructions import CDP, chrome_debugger_endpoint, stop_process

URL = 'https://chatgpt.com/'
BRAVE = Path('/Applications/Brave Browser.app/Contents/MacOS/Brave Browser')
STATE = """({url:location.href,title:document.title,ready:document.readyState,
    viewport:[innerWidth,innerHeight],scale:devicePixelRatio,
    fonts:document.fonts.status,heading:document.querySelector('h1')?.textContent,
    bootstrap:document.documentElement.dataset.octaneHomeBehaviorReady==='1',
    editor:[...document.querySelectorAll('textarea,[contenteditable=true]')].some(e=>{
        const r=e.getBoundingClientRect();return r.width>0&&r.height>0&&!e.disabled}),
    serviceBlocked:/unusual activity|verify you are human|just a moment/i.test(document.body?.innerText||''),
    text:document.body?.innerText,
    images:[...document.images].map(i=>({src:i.currentSrc||i.src,complete:i.complete,
        width:i.naturalWidth,height:i.naturalHeight}))})"""


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def ready(state):
    return (state.get('url') == URL and state.get('title', '').startswith('ChatGPT')
            and state.get('ready') == 'complete' and state.get('editor') is True
            and bool(state.get('heading')) and state.get('fonts') == 'loaded'
            and state.get('bootstrap') is True
            and state.get('viewport') == [1024, 768] and state.get('scale') == 2
            and state.get('serviceBlocked') is False)


class Capture(CDP):
    def __init__(self, endpoint, output):
        super().__init__(endpoint)
        self.output = output
        self.callbacks, self.requests, self.responses = {}, {}, {}
        self.events, self.errors = [], []
        self.capture_paused_responses = False
        self.deadline = None

    def request(self, method, params, callback=None):
        self.sequence += 1
        if callback:
            self.callbacks[self.sequence] = callback
        self.send(json.dumps(dict(id=self.sequence, method=method, params=params)).encode())
        return self.sequence

    def body(self, result, request, response):
        if 'error' in result:
            self.errors.append(dict(url=response['url'], error=result['error']))
            return
        data = result['result']
        body = base64.b64decode(data['body']) if data.get('base64Encoded') else data['body'].encode()
        sha = hashlib.sha256(body).hexdigest()
        (self.output / 'bodies' / sha).write_bytes(body)
        # Do not silently replace a response when the same URL varies.
        headers = response.get('headers', {})
        if isinstance(headers, dict):
            headers = [dict(name=k, value=v) for k, values in headers.items()
                       for v in str(values).split('\n')]
        entry = dict(status=int(response['status']), sha256=sha, bytes=len(body),
            method=request.get('method', 'GET'),
            # Replay discards cookies and serves decoded bodies. Retaining
            # anonymous session cookies or old transfer lengths is unnecessary.
            headers=[h for h in headers if h['name'].lower() not in
                     {'content-length', 'content-encoding', 'transfer-encoding', 'set-cookie'}])
        url = response['url']
        previous = self.responses.get(url)
        if previous and previous['sha256'] != sha:
            self.errors.append(dict(url=url, error='Response varied within the single capture'))
            return
        self.responses[url] = entry

    def paused_response(self, params):
        request = params['request']
        ident = params['requestId']
        if 'responseStatusCode' not in params:
            self.events.append(dict(url=request['url'], response_error=params.get('responseErrorReason')))
            self.request('Fetch.continueRequest', dict(requestId=ident))
            return
        response = dict(url=request['url'], status=params['responseStatusCode'],
                        headers=params.get('responseHeaders', []))

        def received(result):
            # Continuing this response resumes the existing request; it does
            # not issue another navigation or fetch. Save its original bytes
            # before page code can replace the owning document and its buffer.
            try:
                self.body(result, request, response)
            finally:
                self.request('Fetch.continueResponse', dict(requestId=ident))

        status = int(response['status'])
        if status in (204, 205, 304) or 300 <= status < 400:
            received(dict(result=dict(body='', base64Encoded=False)))
        else:
            self.request('Fetch.getResponseBody', dict(requestId=ident), received)

    def receive(self):
        result = super().receive()
        callback = self.callbacks.pop(result.get('id'), None)
        if callback:
            callback(result)
        params, method = result.get('params', {}), result.get('method')
        if method == 'Fetch.requestPaused' and self.capture_paused_responses:
            self.paused_response(params)
        elif method == 'Network.requestWillBeSent':
            self.requests[params['requestId']] = params['request']
        elif method == 'Network.responseReceived':
            response = params['response']
            if response['url'].startswith(('http://', 'https://')):
                request = self.requests.get(params['requestId'], {})
                self.events.append(dict(url=response['url'], status=response['status'],
                                        method=request.get('method'), type=params['type']))
                self.requests[params['requestId']] = dict(request, response=response)
        elif method == 'Network.loadingFinished':
            request = self.requests.pop(params['requestId'], {})
            if 'response' in request and not self.capture_paused_responses:
                response = request.pop('response')
                self.request('Network.getResponseBody', dict(requestId=params['requestId']),
                             lambda value: self.body(value, request, response))
        elif method == 'Network.loadingFailed':
            request = self.requests.pop(params['requestId'], {})
            self.events.append(dict(url=request.get('url'), loading_error=params['errorText']))
        elif method == 'Runtime.exceptionThrown':
            self.errors.append(dict(runtime_exception=params))
        return result

    def call(self, method, params=None):
        self.apply_watchdog(method)
        ident = self.request(method, params or {})
        while True:
            self.apply_watchdog(method)
            result = self.receive()
            if result.get('id') == ident:
                if 'error' in result:
                    raise RuntimeError(result['error'])
                return result.get('result', {})

    def apply_watchdog(self, method):
        deadline = getattr(self, 'deadline', None)
        if deadline is None:
            return
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError('Capture command exceeded its watchdog: ' + method)
        # The generic CDP socket defaults to fifteen seconds. A slow SOCKS
        # navigation must use the configured capture deadline instead.
        self.sock.settimeout(remaining)


def capture(args):
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    archive = out / 'archive'
    (archive / 'bodies').mkdir(parents=True)
    profile = out / 'profile'
    profile.mkdir(mode=0o700)
    identity = brave_identity(BRAVE)
    write(out / 'identity.json', identity)
    command = launch_command(str(BRAVE), str(profile), args.proxy, True)
    command += ['--force-device-scale-factor=2']
    write(out / 'command.json', command)
    env = {k: v for k, v in os.environ.items() if not k.lower().endswith('_proxy')}
    process = subprocess.Popen(command, env=env, stdout=(out / 'stdout.log').open('w'),
                               stderr=(out / 'stderr.log').open('w'), start_new_session=True)
    browser = client = None
    success, started = False, time.time()
    try:
        deadline = time.monotonic() + args.timeout
        while (endpoint := chrome_debugger_endpoint(profile / 'DevToolsActivePort')) is None:
            if process.poll() is not None or time.monotonic() >= deadline:
                raise RuntimeError('Brave debugger unavailable')
            time.sleep(.1)
        port, socket = endpoint
        browser = CDP(f'ws://127.0.0.1:{port}{socket}')
        x, y = test_display()['position']
        target = browser.call('Target.createTarget', dict(url='about:blank', newWindow=True,
            background=True, left=x, top=y, width=1104, height=908))['targetId']
        client = Capture(f'ws://127.0.0.1:{port}/devtools/page/{target}', archive)
        client.deadline = deadline
        for method in ['Page.enable', 'Network.enable', 'Runtime.enable']:
            # Keep response bodies across the site's own document replacement.
            params = dict(maxTotalBufferSize=256 * 1024 * 1024,
                          maxResourceBufferSize=64 * 1024 * 1024,
                          enableDurableMessages=True) if method == 'Network.enable' else {}
            client.call(method, params)
        client.capture_paused_responses = True
        client.call('Fetch.enable', dict(patterns=[
            dict(urlPattern='http://*', requestStage='Response'),
            dict(urlPattern='https://*', requestStage='Response')]))
        client.call('Network.setCacheDisabled', dict(cacheDisabled=True))
        client.call('Emulation.setDeviceMetricsOverride', dict(width=1024, height=768,
                                                              deviceScaleFactor=2, mobile=False))
        client.call('Emulation.setFocusEmulationEnabled', dict(enabled=True))
        navigation = client.call('Page.navigate', dict(url=URL))
        write(out / 'navigation.json', navigation)
        if navigation.get('errorText'):
            raise RuntimeError('Navigation failed: ' + navigation['errorText'])
        states, settled = [], None
        while True:
            state = client.call('Runtime.evaluate', dict(expression=STATE, returnByValue=True))['result']['value']
            states.append(state)
            write(out / 'states.json', states)
            settled = (settled or time.monotonic()) if ready(state) else None
            if settled and time.monotonic() - settled >= args.settle_seconds:
                break
            if state.get('serviceBlocked') or time.monotonic() >= deadline:
                raise RuntimeError('ChatGPT homepage did not become ready; capture is retained without retries')
            time.sleep(.25)
        (out / 'live.png').write_bytes(base64.b64decode(
            client.call('Page.captureScreenshot', dict(format='png', captureBeyondViewport=False))['data']))
        frozen = client.call('Runtime.evaluate', dict(expression=FREEZE, returnByValue=True))
        if frozen.get('exceptionDetails'):
            raise RuntimeError('Cannot retain diagnostic rendered snapshot')
        (out / 'frozen-diagnostic.html').write_text(frozen['result']['value'])
        # Drain in-flight getResponseBody replies without issuing new network requests.
        while client.callbacks:
            client.call('Runtime.evaluate', dict(expression='0', returnByValue=True))
            if time.monotonic() >= deadline:
                raise RuntimeError('Unfinished response reads')
        success = not client.errors and identity == brave_identity(BRAVE)
        if not success:
            raise RuntimeError('Capture body errors or changed browser identity')
    finally:
        if client:
            manifest = dict(version=1, url=URL, captured_unix=started,
                proxy_used_for_capture=args.proxy, author_scripts='original bytes retained',
                responses=client.responses)
            if success:
                manifest['sealed_unix'] = time.time()
            write(archive / ('manifest.json' if success else 'capture-progress.json'), manifest)
            write(out / 'requests.json', client.events)
            write(out / 'errors.json', client.errors)
            write(out / 'pending.json', dict(body_callbacks=len(client.callbacks), requests=[
                dict(url=r.get('url'), method=r.get('method'), response_received='response' in r)
                for r in client.requests.values()]))
        if browser:
            try:
                browser.call('Browser.close')
            except (OSError, RuntimeError):
                pass
            browser.sock.close()
        if client:
            client.sock.close()
        stop_process(process)
        write(out / 'exits.json', dict(browser=process.returncode, sealed=success,
                                      identity_stable=identity == brave_identity(BRAVE)))
    print(json.dumps(dict(archive=str(archive), responses=len(client.responses), sealed=success)), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--proxy', required=True)
    parser.add_argument('--timeout', type=float, default=100)
    parser.add_argument('--settle-seconds', type=float, default=5)
    args = parser.parse_args()
    if not args.proxy.startswith(('socks5://', 'socks5h://')):
        parser.error('A SOCKS5 capture proxy is required')
    capture(args)


if __name__ == '__main__':
    main()
