#!/usr/bin/env python3
"""Audit Chrome's rendering of Vox's legacy frozen GitHub response bodies.

This is a content diagnostic, not an instruction benchmark. The legacy cache
contains no response headers; inferred MIME/CORS policy is disclosed explicitly.
No missing request is allowed to fall through to the live network.
"""
import argparse
import base64
import hashlib
import json
import mimetypes
import os
from pathlib import Path
import subprocess
import tempfile
import time
import urllib.parse
import urllib.request

from measure_browser_instructions import CDP, stop_process


def cache_response(cache, url, resource_type):
    """Use the same category/URL SHA key as browser_cache_entry_path()."""
    category = 'pages' if resource_type == 'Document' else 'resources'
    key = hashlib.sha256(url.encode()).hexdigest()
    path = cache / category / key
    if not path.is_file():
        return None
    body = path.read_bytes()
    if not body or len(body) > 16 * 1024 * 1024:
        return None
    mime = ('text/html; charset=utf-8' if category == 'pages' else
            mimetypes.guess_type(urllib.parse.urlsplit(url).path)[0] or
            {'Script': 'application/javascript', 'Stylesheet': 'text/css',
             'Font': 'font/woff2'}.get(resource_type, 'application/octet-stream'))
    return body, mime, path


class ReplayCDP(CDP):
    """Dispatch events while retaining responses by the ID actually sent.

    Fetch acknowledgements can arrive between another command's response and
    subsequent events. Never compare a response to a mutable global sequence.
    """
    def __init__(self, url, cache):
        super().__init__(url)
        self.cache = cache
        self.responses = {}
        self.pending_replay = set()
        self.requests = []
        self.events = []

    def issue(self, method, params=None):
        self.sequence += 1
        identifier = self.sequence
        self.send(json.dumps(dict(id=identifier, method=method, params=params or {})).encode())
        return identifier

    def lookup_response(self, url, resource_type):
        return cache_response(self.cache, url, resource_type)

    def replay_headers(self, body, mime, path):
        return [{'name': 'Content-Type', 'value': mime},
                {'name': 'Content-Length', 'value': str(len(body))},
                {'name': 'Access-Control-Allow-Origin', 'value': '*'},
                {'name': 'Cache-Control', 'value': 'no-store'}]

    def pump(self):
        response = self.receive()
        identifier = response.get('id')
        if identifier is not None:
            if identifier in self.pending_replay:
                self.pending_replay.remove(identifier)
                if 'error' in response:
                    raise RuntimeError(response['error'])
            else:
                self.responses[identifier] = response
            return
        method = response.get('method')
        params = response.get('params', {})
        if method != 'Fetch.requestPaused':
            self.events.append(response)
            return
        url = params['request']['url']
        resource_type = params['resourceType']
        cached = self.lookup_response(url, resource_type)
        row = dict(url=url, resource_type=resource_type, method=params['request']['method'])
        if cached is None or params['request']['method'] != 'GET':
            row['action'] = 'blocked-missing-or-non-get'
            command = self.issue('Fetch.failRequest', dict(requestId=params['requestId'], errorReason='BlockedByClient'))
        else:
            body, mime, path = cached
            row.update(action='replayed', cache_path=str(path), bytes=len(body), mime=mime,
                       sha256=hashlib.sha256(body).hexdigest())
            headers = self.replay_headers(body, mime, path)
            command = self.issue('Fetch.fulfillRequest', dict(requestId=params['requestId'],
                                 responseCode=200, responseHeaders=headers,
                                 body=base64.b64encode(body).decode()))
        self.pending_replay.add(command)
        self.requests.append(row)

    def call(self, method, params=None):
        identifier = self.issue(method, params)
        while identifier not in self.responses:
            self.pump()
        response = self.responses.pop(identifier)
        if 'error' in response:
            raise RuntimeError(response['error'])
        return response.get('result', {})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', required=True, type=Path)
    parser.add_argument('--cache', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--timeout', type=float, default=90)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    url = 'https://github.com/vlang/v'
    result = dict(exit=None, url=url, viewport=[1024, 768], performance_credit=0,
                  scope='Content diagnostic only. No instruction or Chrome parity claim.',
                  response_header_policy='Legacy cache has bodies only. MIME inferred from URL/type; CORS wildcard, no-store, status200. Missing/non-GET requests fail; no live fallback.')
    client = process = None
    try:
        with tempfile.TemporaryDirectory(prefix='chrome-profile-', dir=args.output) as profile:
            with (args.output / 'browser.log').open('w') as log:
                command = [str(args.binary.resolve()), '--headless=new', '--no-first-run',
                           '--no-default-browser-check', '--disable-background-networking',
                           '--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE localhost',
                           '--remote-debugging-port=0', '--user-data-dir=' + profile, 'about:blank']
                process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                deadline = time.monotonic() + args.timeout
                active = Path(profile) / 'DevToolsActivePort'
                while not active.exists():
                    if process.poll() is not None or time.monotonic() > deadline:
                        raise RuntimeError('Chrome debugger did not start')
                    time.sleep(.02)
                port = int(active.read_text().splitlines()[0])
                opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
                with opener.open(f'http://127.0.0.1:{port}/json/list', timeout=15) as response:
                    targets = json.load(response)
                client = ReplayCDP(next(t['webSocketDebuggerUrl'] for t in targets if t['type'] == 'page'), args.cache)
                result['version'] = client.call('Browser.getVersion')
                result['command'] = command
                for method in ['Page.enable', 'Runtime.enable', 'Network.enable']:
                    client.call(method)
                client.call('Network.setBypassServiceWorker', {'bypass': True})
                client.call('Network.setCacheDisabled', {'cacheDisabled': True})
                client.call('Page.setLifecycleEventsEnabled', {'enabled': True})
                client.call('Emulation.setDeviceMetricsOverride', dict(width=1024, height=768, deviceScaleFactor=1, mobile=False))
                client.call('Fetch.enable', dict(patterns=[{'urlPattern': '*', 'requestStage': 'Request'}]))
                client.call('Page.navigate', {'url': url})
                expression = '''JSON.stringify({url:location.href,ready:document.readyState,
                    title:document.title,width:innerWidth,height:innerHeight,scale:devicePixelRatio,
                    text:document.body?.innerText||'',bodyHTML:document.body?.outerHTML||'',
                    fileLinks:[...document.querySelectorAll('a')].filter(a=>/\\/vlang\\/v\\/(blob|tree)\\//.test(a.href)).map(a=>({text:a.textContent,href:a.href})),
                    images:[...document.images].map(i=>({src:i.currentSrc||i.src,width:i.naturalWidth,height:i.naturalHeight,complete:i.complete})),
                    paint:performance.getEntriesByType('paint').map(p=>p.toJSON()),
                    resources:performance.getEntriesByType('resource').map(p=>p.toJSON())})'''
                while True:
                    evaluated = client.call('Runtime.evaluate', {'expression': expression, 'returnByValue': True})
                    state = json.loads(evaluated['result']['value'])
                    if state['ready'] == 'complete' and state['paint']:
                        break
                    if time.monotonic() > deadline:
                        raise RuntimeError('Frozen document did not finish before watchdog')
                    time.sleep(.02)
                image = client.call('Page.captureScreenshot', dict(format='png', captureBeyondViewport=False))
                (args.output / 'document.png').write_bytes(base64.b64decode(image['data']))
                for field, filename in [('text', 'document.txt'), ('bodyHTML', 'body.html')]:
                    content = state.pop(field)
                    (args.output / filename).write_text(content)
                    state[field + '_sha256'] = hashlib.sha256(content.encode()).hexdigest()
                    state[field + '_length'] = len(content)
                result.update(exit=0, document=state)
                client.call('Browser.close')
                process.wait(timeout=15)
                result['process_exit'] = process.returncode
    except Exception as exc:
        result.update(exit=1, error=str(exc))
    finally:
        if client is not None:
            result.update(requests=client.requests, events=client.events)
            client.sock.close()
        if process is not None:
            stop_process(process)
        result['binary_sha256'] = hashlib.sha256(args.binary.read_bytes()).hexdigest()
        (args.output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: result.get(k) for k in ['exit', 'error', 'scope']}))
    return result['exit']


if __name__ == '__main__':
    raise SystemExit(main())
