import hashlib
import json
from pathlib import Path
import socket
import ssl
import tempfile
import time
import unittest
from urllib.parse import urlsplit

from measure_page_switch import archive_route, proxy_configuration, sha256


class LocalPageSwitchTests(unittest.TestCase):
    def test_original_https_pages_and_assets_are_served_from_disk(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive = root/'archive'
            (archive/'bodies').mkdir(parents=True)
            hot = 'https://old.reddit.com/r/example/'
            bodies = {hot: b'<title>hot</title><link rel="stylesheet" href="/style.css">',
                      hot+'new/': b'<title>new</title><p>Different posts</p>',
                      'https://old.reddit.com/style.css': b'p{color:blue}'}
            entries = {}
            for url, body in bodies.items():
                digest = hashlib.sha256(body).hexdigest()
                (archive/'bodies'/digest).write_bytes(body)
                entries[url] = dict(status=200, sha256=digest, bytes=len(body), headers=[
                    dict(name='Content-Type', value='text/css' if url.endswith('.css') else 'text/html')])
            (archive/'manifest.json').write_text(json.dumps(dict(
                version=1, url=hot, sealed_unix=time.time(), responses=entries)))
            with archive_route(archive, root) as ready:
                self.assertFalse(ready['forwarding'])
                self.assertEqual(ready['manifest_sha256'], sha256(archive/'manifest.json'))
                proxy = urlsplit(ready['proxy'])
                self.assertEqual(proxy_configuration(ready['proxy']), dict(
                    enabled=True, host=proxy.hostname, port=str(proxy.port), sites=''))

                def tunnel(raw, host, port=443):
                    raw.sendall(b'\x05\x01\x00')
                    self.assertEqual(raw.recv(2), b'\x05\x00')
                    encoded = host.encode('ascii')
                    raw.sendall(b'\x05\x01\x00\x03' + bytes([len(encoded)]) + encoded
                                + port.to_bytes(2, 'big'))
                    reply = b''
                    while len(reply) < 10:
                        part = raw.recv(10-len(reply))
                        self.assertTrue(part, 'SOCKS server closed before replying')
                        reply += part
                    return reply[1]

                def get(url, transport):
                    address = urlsplit(url)
                    with socket.create_connection((proxy.hostname, proxy.port), timeout=5) as raw:
                        if transport == 'socks':
                            self.assertEqual(tunnel(raw, address.hostname), 0)
                        else:
                            raw.sendall(f'CONNECT {address.hostname}:443 HTTP/1.1\r\n\r\n'.encode())
                            self.assertIn(b'200', raw.recv(4096))
                        context = ssl.create_default_context(cafile=ready['ca'])
                        with context.wrap_socket(raw, server_hostname=address.hostname) as sock:
                            sock.sendall(f'GET {address.path} HTTP/1.1\r\nHost: {address.hostname}\r\n\r\n'.encode())
                            data = bytearray()
                            while part := sock.recv(4096):
                                data.extend(part)
                            return bytes(data).split(b'\r\n\r\n', 1)

                for transport in ['socks', 'http']:
                    for url, body in bodies.items():
                        with self.subTest(transport=transport, url=url):
                            headers, actual = get(url, transport)
                            self.assertIn(b'200', headers)
                            self.assertEqual(actual, body)
                    headers, body = get(hot+'unavailable/', transport)
                    self.assertIn(b'404', headers)
                    self.assertEqual(body, b'')
                for host, port in [('unarchived.invalid', 443), ('old.reddit.com', 80)]:
                    with socket.create_connection((proxy.hostname, proxy.port), timeout=5) as sock:
                        self.assertEqual(tunnel(sock, host, port), 2)
                with socket.create_connection((proxy.hostname, proxy.port), timeout=5) as sock:
                    sock.sendall(b'\x05\x01\x02')
                    self.assertEqual(sock.recv(2), b'\x05\xff')
                with socket.create_connection((proxy.hostname, proxy.port), timeout=5) as sock:
                    sock.sendall(b'CONNECT unarchived.invalid:443 HTTP/1.1\r\n\r\n')
                    self.assertIn(b'403', sock.recv(4096))
            with self.assertRaises(OSError):
                socket.create_connection((proxy.hostname, proxy.port), timeout=.2)

    def test_replay_route_matches_saved_socks_proxy(self):
        for scheme in ['socks5', 'socks5h']:
            self.assertEqual(proxy_configuration(scheme+'://127.0.0.1:1234'), dict(
                enabled=True, host='127.0.0.1', port='1234', sites=''))
        for address in ['http://127.0.0.1:1234', 'https://localhost:1234', 'socks5://localhost',
                        'socks5://localhost:0', 'socks5://localhost:1234/path',
                        'socks5://user@localhost:1234', 'socks5://localhost:1234?bypass=1',
                        'socks5://localhost:70000']:
            with self.subTest(address=address), self.assertRaises(ValueError):
                proxy_configuration(address)


if __name__ == '__main__':
    unittest.main()
