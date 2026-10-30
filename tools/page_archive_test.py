import argparse
from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import socket
import ssl
import tempfile
import threading
import time
import unittest
from unittest import mock

import page_archive
from measure_disk_scroll import offline_environment


class PageArchiveTests(unittest.TestCase):
    def test_replay_accepts_browser_connection_bursts(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive, url, bodies = self.fixture(root)
            replay = page_archive.Replay(archive, root / 'replay')
            clients = []
            thread = None
            try:
                # Browser resource loaders open several host connections before
                # the replay thread necessarily gets another CPU timeslice.
                for _ in range(16):
                    clients.append(socket.create_connection(replay.server.server_address, timeout=.25))
                thread = threading.Thread(target=replay.server.serve_forever, daemon=True)
                thread.start()
                for client in clients:
                    client.settimeout(5)
                    client.sendall(('GET ' + url + ' HTTP/1.1\r\nHost: archive.test\r\n\r\n').encode())
                    response = bytearray()
                    while chunk := client.recv(65536):
                        response.extend(chunk)
                    self.assertTrue(response.startswith(b'HTTP/1.1 200 '))
                    self.assertEqual(response.split(b'\r\n\r\n', 1)[1], bodies[url][0])
            finally:
                for client in clients:
                    client.close()
                if thread:
                    replay.server.shutdown()
                    thread.join()
                replay.server.server_close()

    def test_large_replay_body_finishes_with_a_clean_tls_shutdown(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive = root / 'archive'
            (archive / 'bodies').mkdir(parents=True)
            url = 'https://archive.invalid/large.css'
            body = b'p{color:green}\n' * 65536
            sha = page_archive.digest(body)
            (archive / 'bodies' / sha).write_bytes(body)
            (archive / 'manifest.json').write_text(json.dumps(dict(version=1, url=url,
                sealed_unix=time.time(), responses={url:dict(status=200,sha256=sha,
                    bytes=len(body),headers=[dict(name='Content-Type',value='text/css')])})))
            replay = page_archive.Replay(archive, root / 'replay')
            thread = threading.Thread(target=replay.server.serve_forever, daemon=True)
            thread.start()
            try:
                with socket.create_connection(replay.server.server_address, timeout=5) as raw:
                    raw.sendall(b'CONNECT archive.invalid:443 HTTP/1.1\r\n\r\n')
                    self.assertIn(b'200', raw.recv(4096))
                    context = ssl.create_default_context(cafile=replay.ready['ca'])
                    with context.wrap_socket(raw,server_hostname='archive.invalid',
                            suppress_ragged_eofs=False) as sock:
                        sock.sendall(b'GET /large.css HTTP/1.1\r\nHost: archive.invalid\r\n\r\n')
                        chunks=[]
                        while part := sock.recv(65536):
                            chunks.append(part)
                        response=b''.join(chunks)
                        _,_,actual=response.partition(b'\r\n\r\n')
                        self.assertEqual(len(actual),len(body))
                        self.assertEqual(page_archive.digest(actual),sha)
                        sock.unwrap().close()
            finally:
                replay.server.shutdown()
                replay.server.server_close()
                thread.join(timeout=5)

    def fixture(self, root):
        cache = root / 'cache'
        (cache / 'pages').mkdir(parents=True)
        (cache / 'resources').mkdir()
        url = 'https://archive.invalid/thread/1'
        bodies = {
            url: (b'<title>Thread</title><link rel="stylesheet" href="/a.css">'
                  b'<script src="/a.js"></script><script>window.original = true;</script>', 'text/html'),
            'https://archive.invalid/a.css': (b'@import "b.css";p{background:url(image.png)}', 'text/css'),
            'https://archive.invalid/b.css': (b'p{color:green}', 'text/css'),
            'https://archive.invalid/image.png': (b'fixture image', 'image/png'),
            'https://archive.invalid/a.js': (b'window.fromDisk = true;', 'text/javascript'),
        }
        for address, (body, mime) in bodies.items():
            key = page_archive.digest(address.encode())
            path = cache / ('pages' if address == url else 'resources') / key
            path.write_bytes(body)
            Path(str(path) + '.headers.json').write_text(json.dumps([
                dict(name='Content-Type', value=mime),
                dict(name='Access-Control-Allow-Origin', value='*')]))
            if address != url:
                Path(str(path) + '.url').write_text(address)
        archive = root / 'archive'
        with mock.patch.object(page_archive.subprocess, 'run', side_effect=AssertionError('Unexpected download')), \
                redirect_stdout(io.StringIO()):
            page_archive.capture(argparse.Namespace(output=archive, url=url, proxy=None,
                                 extra_url=[], from_cache=cache, from_archive=None))
        return archive, url, bodies

    def test_recursive_capture_retains_original_scripts_css_images_and_headers(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive, url, bodies = self.fixture(Path(temporary))
            manifest = page_archive.load_archive(archive)
            self.assertEqual(set(manifest['responses']), set(bodies))
            for address, (body, _) in bodies.items():
                entry = manifest['responses'][address]
                self.assertEqual((archive / 'bodies' / entry['sha256']).read_bytes(), body)
            with mock.patch.object(page_archive.subprocess, 'run', side_effect=AssertionError('Refetch')), \
                    redirect_stdout(io.StringIO()):
                page_archive.capture(argparse.Namespace(output=archive.parent / 'reused', url=url, proxy=None,
                                     extra_url=[], from_cache=None, from_archive=archive))
            reused = page_archive.load_archive(archive.parent / 'reused')
            self.assertEqual(set(reused['responses']), set(bodies))
            self.assertIn(b'<script>window.original = true;</script>', bodies[url][0])
            entry = manifest['responses'][url]
            (archive / 'bodies' / entry['sha256']).write_bytes(b'changed')
            with self.assertRaisesRegex(ValueError, 'changed'):
                page_archive.load_archive(archive)

    def test_replay_serves_https_from_disk_and_never_forwards_misses(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive, url, bodies = self.fixture(root)
            replay = page_archive.Replay(archive, root / 'replay')
            thread = threading.Thread(target=replay.server.serve_forever, daemon=True)
            thread.start()
            try:
                def tunnel(raw, host, port=443):
                    raw.sendall(b'\x05\x01\x00')
                    self.assertEqual(page_archive.Replay.receive(raw, 2), b'\x05\x00')
                    encoded = host.encode('ascii')
                    raw.sendall(b'\x05\x01\x00\x03' + bytes([len(encoded)]) + encoded
                                + port.to_bytes(2, 'big'))
                    return page_archive.Replay.receive(raw, 10)[1]

                def request(target, transport):
                    with socket.create_connection(replay.server.server_address) as raw:
                        if transport == 'socks':
                            self.assertEqual(tunnel(raw, 'archive.invalid'), 0)
                        else:
                            raw.sendall(b'CONNECT archive.invalid:443 HTTP/1.1\r\n\r\n')
                            self.assertIn(b'200', raw.recv(4096))
                        context = ssl.create_default_context(cafile=replay.ready['ca'])
                        with context.wrap_socket(raw, server_hostname='archive.invalid') as sock:
                            sock.sendall(f'GET {target} HTTP/1.1\r\nHost: archive.invalid\r\n\r\n'.encode())
                            chunks = []
                            while part := sock.recv(4096):
                                chunks.append(part)
                            return b''.join(chunks)
                for transport in ['http', 'socks']:
                    with self.subTest(transport=transport):
                        response = request('/thread/1', transport)
                        self.assertTrue(response.endswith(bodies[url][0]))
                        self.assertIn(b'Access-Control-Allow-Origin: *', response)
                        self.assertIn(b'404', request('/not-archived', transport))
                for host, port in [('external.invalid', 443), ('archive.invalid', 80)]:
                    with socket.create_connection(replay.server.server_address) as sock:
                        self.assertEqual(tunnel(sock, host, port), 2)
                with socket.create_connection(replay.server.server_address) as sock:
                    sock.sendall(b'CONNECT external.invalid:443 HTTP/1.1\r\n\r\n')
                    self.assertIn(b'403', sock.recv(4096))
                rows = [json.loads(line) for line in (root / 'replay/requests.jsonl').read_text().splitlines()]
                self.assertEqual([row['archived'] for row in rows],
                                 [True, False, True, False, False, False, False])
                self.assertFalse(replay.ready['forwarding'])
                with socket.create_connection(replay.server.server_address) as sock:
                    sock.sendall(b'\x05\x01\x02')
                    self.assertEqual(sock.recv(2), b'\x05\xff')
            finally:
                replay.server.shutdown()
                replay.server.server_close()
                thread.join(timeout=5)

    def test_replay_rejects_unsealed_metadata_and_body_path_escape(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive, url, _ = self.fixture(Path(temporary))
            path = archive / 'manifest.json'
            manifest = json.loads(path.read_text())
            manifest['responses'][url]['sha256'] = '../../outside'
            path.write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, 'Invalid body identity'):
                page_archive.load_archive(archive)
            del manifest['sealed_unix']
            path.write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, 'sealed'):
                page_archive.load_archive(archive)

    def test_offline_environment_removes_inherited_socks_and_bypass_settings(self):
        with mock.patch.dict('os.environ', dict(ALL_PROXY='socks5h://127.0.0.1:1337',
                             http_proxy='other', NO_PROXY='*', VOX_PROXY='saved',
                             DYLD_INSERT_LIBRARIES='/old.dylib'), clear=True):
            env = offline_environment('http://127.0.0.1:1234', '/private/cert.pem')
        self.assertEqual(env, dict(VOX_PROXY='http://127.0.0.1:1234',
                                  SSL_CERT_FILE='/private/cert.pem', NO_PROXY=''))


if __name__ == '__main__':
    unittest.main()
