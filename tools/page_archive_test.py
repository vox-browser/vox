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
    def test_replay_consumes_post_body_before_returning_response(self):
        server, client = socket.socketpair()
        try:
            client.sendall(b'POST /prepare HTTP/1.1\r\nContent-Length: 4\r\n\r\nbodyNEXT')
            self.assertEqual(page_archive.Replay.request(server), ['POST', '/prepare', 'HTTP/1.1'])
            self.assertEqual(server.recv(4), b'NEXT')
        finally:
            server.close()
            client.close()

    def test_replay_requires_the_original_request_method(self):
        replay = page_archive.Replay.__new__(page_archive.Replay)
        get, post = dict(status=200), dict(method='POST', status=200)
        replay.manifest = dict(responses={'https://archive.invalid/': get,
                                         'https://archive.invalid/prepare': post})
        self.assertIs(replay.response_entry('GET', 'https://archive.invalid/'), get)
        self.assertIs(replay.response_entry('HEAD', 'https://archive.invalid/'), get)
        self.assertIsNone(replay.response_entry('POST', 'https://archive.invalid/'))
        self.assertIs(replay.response_entry('POST', 'https://archive.invalid/prepare'), post)
        self.assertIsNone(replay.response_entry('GET', 'https://archive.invalid/prepare'))
        self.assertIsNone(replay.response_entry('POST', 'https://archive.invalid/missing'))

    def test_valueless_inline_style_preserves_resource_discovery(self):
        parser = page_archive.ResourceLinks('https://www.wikipedia.org/')
        parser.feed('<img style src="/globe.png"><div style></div>'
                    '<div style="background:url(/sprite.svg)"></div>')
        self.assertEqual(parser.links, {
            'https://www.wikipedia.org/globe.png',
            'https://www.wikipedia.org/sprite.svg',
        })

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

    def test_import_preserves_recorded_request_methods_for_replay(self):
        for source_kind in ['archive', 'progress']:
            with self.subTest(source_kind=source_kind), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                archive, url, _ = self.fixture(root)
                manifest = page_archive.load_archive(archive)
                methods = {'https://archive.invalid/a.js': 'POST',
                           'https://archive.invalid/image.png': 'HEAD'}
                for address, method in methods.items():
                    manifest['responses'][address]['method'] = method
                manifest_path = archive / 'manifest.json'
                manifest_path.write_text(json.dumps(manifest))
                source = dict(from_archive=archive, from_progress=None,
                              expected_progress_sha256=None)
                if source_kind == 'progress':
                    del manifest['sealed_unix']
                    progress = archive / 'capture-progress.json'
                    progress.write_text(json.dumps(manifest))
                    source = dict(from_archive=None, from_progress=archive,
                                  expected_progress_sha256=page_archive.digest(progress.read_bytes()))
                output = root / 'imported'
                with mock.patch.object(page_archive.subprocess, 'run',
                        side_effect=AssertionError('Unexpected refetch')), redirect_stdout(io.StringIO()):
                    page_archive.capture(argparse.Namespace(output=output, url=url, proxy=None,
                        extra_url=list(manifest['responses']), from_cache=None, **source))
                imported = page_archive.load_archive(output)
                replay = page_archive.Replay.__new__(page_archive.Replay)
                replay.manifest = imported
                for address, method in methods.items():
                    entry = replay.response_entry(method, address)
                    self.assertIsNotNone(entry)
                    self.assertEqual(entry['sha256'], manifest['responses'][address]['sha256'])
                    self.assertIsNone(replay.response_entry('GET', address))
                self.assertIsNotNone(replay.response_entry('GET', url))

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


class CaptureProgressTests(unittest.TestCase):
    url = 'https://archive.invalid/page'

    def prepare(self, root):
        source = root / 'unfinished'
        (source / 'bodies').mkdir(parents=True)
        rows = {
            self.url: (b'<link rel="stylesheet" href="/a.css"><script src="/missing.js"></script>', 'text/html'),
            'https://archive.invalid/a.css': (b'p{color:green}', 'text/css'),
            'https://archive.invalid/earlier-api': (b'{"original":true}', 'application/json'),
        }
        entries = {}
        for url, (body, mime) in rows.items():
            sha = page_archive.digest(body)
            (source / 'bodies' / sha).write_bytes(body)
            entries[url] = dict(sha256=sha, bytes=len(body), status=200,
                headers=[dict(name='Content-Type', value=mime), dict(name='X-Original', value='retained')],
                provenance=dict(source='curl', captured_unix=100))
        path = source / 'capture-progress.json'
        path.write_text(json.dumps(dict(version=1, url=self.url, responses=entries)))
        return source, page_archive.digest(path.read_bytes()), entries

    def args(self, root, source, pin, **changes):
        args = argparse.Namespace(output=root / 'resumed', url=self.url, proxy=None,
            from_archive=None, from_cache=None, extra_url=[], from_progress=source,
            expected_progress_sha256=pin)
        for name, value in changes.items():
            setattr(args, name, value)
        return args

    def download(self, args, status=200, body=b'window.original=true;', callback=None):
        calls = []

        def run(command, **kwargs):
            calls.append(command[-1])
            args.output.joinpath('download.body').write_bytes(body)
            args.output.joinpath('download.headers').write_text(
                f'HTTP/1.1 {status} Fixture\r\nContent-Type: text/javascript\r\nX-New: kept\r\n\r\n')
            if callback:
                callback()
            return page_archive.subprocess.CompletedProcess(command, 0, str(status), '')
        return calls, run

    def test_resume_reuses_every_verified_response_and_downloads_only_missing_work(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, pin, entries = self.prepare(root)
            original = (source / 'capture-progress.json').read_bytes()
            args = self.args(root, source, pin)
            calls, run = self.download(args)
            with mock.patch.object(page_archive.subprocess, 'run', side_effect=run), redirect_stdout(io.StringIO()):
                page_archive.capture(args)
            self.assertEqual(calls, ['https://archive.invalid/missing.js'])
            manifest = page_archive.load_archive(args.output)
            self.assertEqual(len(manifest['responses']), 4)
            for url, entry in entries.items():
                current = manifest['responses'][url]
                for name in ('sha256', 'bytes', 'status', 'headers'):
                    self.assertEqual(current[name], entry[name])
                self.assertEqual(current['provenance']['original_provenance'], entry['provenance'])
            self.assertEqual(manifest['imported_capture_progress_sha256'], pin)
            self.assertEqual((source / 'capture-progress.json').read_bytes(), original)
            self.assertFalse((source / 'manifest.json').exists())

    def test_wrong_or_missing_pin_is_rejected_before_creating_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, pin, _ = self.prepare(root)
            for bad in (None, 'not a digest', '0' * 64):
                args = self.args(root, source, bad)
                with self.subTest(pin=bad), self.assertRaisesRegex(ValueError, 'SHA256'):
                    page_archive.capture(args)
                self.assertFalse(args.output.exists())

    def test_import_rejects_modified_missing_and_symlinked_bodies(self):
        for mutation in ('changed', 'missing', 'symlink'):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                source, pin, entries = self.prepare(root)
                body = source / 'bodies' / entries[self.url]['sha256']
                if mutation == 'changed':
                    body.write_bytes(b'changed')
                elif mutation == 'missing':
                    body.unlink()
                else:
                    target = root / 'elsewhere'
                    body.rename(target)
                    body.symlink_to(target)
                with self.assertRaises((ValueError, FileNotFoundError)):
                    page_archive.capture(self.args(root, source, pin))
                self.assertFalse((root / 'resumed').exists())

    def test_import_requires_matching_entry_and_unambiguous_external_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, pin, _ = self.prepare(root)
            for changes in [dict(url='https://other.invalid/'), dict(from_archive=source),
                            dict(from_cache=source), dict(output=source), dict(output=source / 'nested')]:
                with self.subTest(changes=changes), self.assertRaises(ValueError):
                    page_archive.capture(self.args(root, source, pin, **changes))
            self.assertFalse((root / 'resumed').exists())

    def test_progress_is_not_replayable_and_completed_manifest_cannot_be_imported_as_progress(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, pin, _ = self.prepare(root)
            progress = json.loads((source / 'capture-progress.json').read_text())
            (source / 'manifest.json').write_text(json.dumps(progress))
            with self.assertRaisesRegex(ValueError, 'sealed'):
                page_archive.load_archive(source)
            progress['sealed_unix'] = 100
            (source / 'capture-progress.json').write_text(json.dumps(progress))
            pin = page_archive.digest((source / 'capture-progress.json').read_bytes())
            with self.assertRaisesRegex(ValueError, 'unfinished'):
                page_archive.load_capture_progress(source, pin)

    def test_concurrent_source_change_prevents_sealing_the_new_capture(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, pin, _ = self.prepare(root)
            args = self.args(root, source, pin)
            _, run = self.download(args, callback=lambda: (source / 'capture-progress.json').write_text('{}'))
            with mock.patch.object(page_archive.subprocess, 'run', side_effect=run), redirect_stdout(io.StringIO()):
                with self.assertRaisesRegex(ValueError, 'SHA256 mismatch'):
                    page_archive.capture(args)
            self.assertFalse((args.output / 'manifest.json').exists())

    def test_explicit_optional_error_keeps_original_status_body_and_headers(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, pin, _ = self.prepare(root)
            missing = 'https://archive.invalid/missing.js'
            args = self.args(root, source, pin, extra_url=[missing])
            _, run = self.download(args, status=404, body=b'original missing body')
            with mock.patch.object(page_archive.subprocess, 'run', side_effect=run), redirect_stdout(io.StringIO()):
                page_archive.capture(args)
            manifest = page_archive.load_archive(args.output)
            row = manifest['responses'][missing]
            self.assertEqual(row['status'], 404)
            self.assertEqual((args.output / 'bodies' / row['sha256']).read_bytes(), b'original missing body')
            self.assertIn(dict(name='X-New', value='kept'), row['headers'])
            self.assertEqual(manifest['optional_http_error_urls'], [missing])

    def test_unlisted_resource_error_still_fails_and_preserves_original_capture(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, pin, _ = self.prepare(root)
            args = self.args(root, source, pin)
            _, run = self.download(args, status=404)
            with mock.patch.object(page_archive.subprocess, 'run', side_effect=run), redirect_stdout(io.StringIO()):
                with self.assertRaisesRegex(RuntimeError, 'required resource: 404'):
                    page_archive.capture(args)
            self.assertFalse((args.output / 'manifest.json').exists())
            page_archive.load_capture_progress(source, pin)

    def test_entry_http_error_is_required_even_when_explicitly_listed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, pin, _ = self.prepare(root)
            path = source / 'capture-progress.json'
            progress = json.loads(path.read_text())
            progress['responses'][self.url]['status'] = 404
            path.write_text(json.dumps(progress))
            args = self.args(root, source, page_archive.digest(path.read_bytes()), extra_url=[self.url])
            with mock.patch.object(page_archive.subprocess, 'run', side_effect=AssertionError('Refetch')):
                with self.assertRaisesRegex(RuntimeError, 'required resource: 404'):
                    page_archive.capture(args)
            self.assertFalse((args.output / 'manifest.json').exists())


if __name__ == '__main__':
    unittest.main()
