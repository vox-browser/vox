"""Hermetic HTTPS module responses behind the archive SOCKS replay server."""
import json
from pathlib import Path
import sys
import time

from page_archive import Replay, digest


def main():
    output = Path(sys.argv[1]).resolve()
    archive = output / 'archive'
    (archive / 'bodies').mkdir(parents=True)
    responses = {}
    for name, value in [('a', 41), ('b', 1)]:
        body = (f'export const value={value};/*' + 'x' * (256 * 1024) + '*/').encode()
        sha = digest(body)
        (archive / 'bodies' / sha).write_bytes(body)
        responses[f'https://module-proxy.test/{name}.js'] = dict(
            status=200, headers=[dict(name='Content-Type', value='text/javascript')],
            bytes=len(body), sha256=sha)
    (archive / 'manifest.json').write_text(json.dumps(dict(
        version=1, sealed_unix=time.time(), url='https://module-proxy.test/a.js', responses=responses)))
    replay = Replay(archive, output / 'replay')
    print(json.dumps(replay.ready), flush=True)
    try:
        replay.server.serve_forever()
    finally:
        replay.server.server_close()


if __name__ == '__main__':
    main()
