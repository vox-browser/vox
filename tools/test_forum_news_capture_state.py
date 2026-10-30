#!/usr/bin/env python3
"""Compare live and frozen CSSOM/quirks-mode pages in Brave with full uBO."""
import argparse
import http.server
import json
from pathlib import Path
import tempfile
import threading
from urllib.parse import urlsplit

from check_pixel_equality import compare
from forum_news_pixels import BRAVE, HARNESS, REPO, guarded, write_json


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--extension', type=Path, required=True)
    parser.add_argument('--checker', type=Path, required=True)
    parser.add_argument('--diff-tool', type=Path, required=True)
    parser.add_argument('--brave', type=Path, default=BRAVE)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    output = args.output.resolve() if args.output else Path(tempfile.mkdtemp(
        prefix='forum-capture-state-', dir=REPO / 'Build'))
    if args.output:
        output.mkdir(parents=True, exist_ok=False)
    source = ('<html><head><style>.raw{color:rgb(51 51 51 / 59%)}</style>'
        '<style id="dynamic"></style><script>document.getElementById("dynamic").sheet.'
        'insertRule(".dynamic{color:rgb(0 128 0);font-weight:700}");</script>'
        '</head><body><p class="dynamic">' + 'Live author style ' * 100
        + '</p><p class="raw">' + 'Raw author color ' * 100 + '</p></body></html>')
    state = dict(body=source.encode())
    (output / 'source.html').write_bytes(state['body'])

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            target = urlsplit(self.path)
            allowed = target.hostname == 'capture-state.test' and target.path == '/'
            body = state['body'] if allowed else b'Unavailable fixture URL'
            self.send_response(200 if allowed else 404)
            self.send_header('Content-Type', 'text/html;charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_CONNECT(self):
            self.send_response(403)
            self.send_header('Content-Length', '0')
            self.end_headers()

        def log_message(self, *args):
            pass

    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    common = ['node', HARNESS, '--url', 'http://capture-state.test/',
        '--extension', args.extension.resolve(), '--checker', args.checker.resolve(),
        '--brave', args.brave.resolve(), '--settle', '1',
        '--proxy-server', 'http://127.0.0.1:' + str(server.server_address[1])]
    try:
        guarded(common + ['--capture-dir', output / 'capture', '--output', output / 'capture.json'],
                output / 'live', 90)
        metadata = json.loads((output / 'capture/archive.json').read_text())
        if metadata['cssom_styles'] != 1 or metadata['compat_mode'] != 'BackCompat':
            raise RuntimeError('Capture did not retain the dynamic rules and document mode')
        state['body'] = (output / 'capture/frozen.html').read_bytes()
        if state['body'].lower().startswith(b'<!doctype'):
            raise RuntimeError('Capture inserted a standards-mode doctype')
        guarded(common + ['--pixel-reference', output / 'replay.png', '--output', output / 'replay.json'],
                output / 'replay', 90)
        verdict = compare(output / 'capture/live.png', output / 'replay.png',
                          output / 'diff.png', args.diff_tool.resolve())
        write_json(output / 'pixels.json', verdict)
        print(verdict['metrics'], end='')
        return 0 if verdict['exact'] else 1
    finally:
        server.shutdown()
        server.server_close()
        thread.join()


if __name__ == '__main__':
    raise SystemExit(main())
