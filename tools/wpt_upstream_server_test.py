import json
import os
from pathlib import Path
import ssl
import tempfile
import unittest
from urllib.request import HTTPSHandler, ProxyHandler, Request, build_opener

from wpt_upstream_server import UpstreamWPTServer


CHECKOUT = Path(os.environ.get('VOX_WPT_CHECKOUT', Path.home() / 'code/3rd/web-platform-tests'))


class Observer:
    def __init__(self):
        self.payloads = []
        self.alive = []
        self.requests = []

    def note_request(self, target):
        self.requests.append(target)

    def log_request(self, *args):
        pass

    def note_harness(self, target):
        self.alive.append(target)

    def accept(self, payload):
        self.payloads.append(payload)
        return '/next.html'


@unittest.skipUnless((CHECKOUT / 'tools/localpaths.py').is_file(), 'requires an upstream WPT checkout')
class UpstreamServerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix='vox-wpt-server-')
        cls.root = Path(cls.temporary.name) / 'fixtures'
        cls.root.mkdir()
        (cls.root / 'echo.py').write_text('''
def main(request, response):
    key = "d08bbffb-a6b4-4ccd-9678-e19ce7dca813"
    headers = [(b"Content-Type", b"application/octet-stream")]
    if request.method == "POST":
        request.server.stash.put(key, request.body)
        return headers, b"stored"
    return headers, request.server.stash.take(key)
''')
        (cls.root / 'template.sub.js').write_text('{{host}}|{{ports[http][0]}}|{{ports[http][1]}}|{{ports[https][0]}}')
        (cls.root / 'template.sub.js.headers').write_text('X-Upstream: real-handler\n')
        (cls.root / 'shared.sub.js').write_text('{{ports[ws][0]}}|{{ports[wss][0]}}')
        cls.observer = Observer()
        cls.server = UpstreamWPTServer(CHECKOUT, cls.root, cls.observer,
                                      {'/resources/testharnessreport.js': (b'collector', 'text/javascript')},
                                      '/__runner/alive', '/__runner/result',
                                      Path(cls.temporary.name) / 'certificates')
        context = ssl.create_default_context(cafile=cls.server.identity['ca_certificate'])
        cls.client = build_opener(ProxyHandler({}), HTTPSHandler(context=context))

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.temporary.cleanup()

    def test_python_handlers_receive_binary_posts_and_share_the_upstream_stash(self):
        url = self.server.base_url + '/echo.py'
        data = b'zero\x00high\xff\r\n'
        with self.client.open(Request(url, data=data), timeout=10) as response:
            self.assertEqual(response.read(), b'stored')
        with self.client.open(url, timeout=10) as response:
            self.assertEqual(response.read(), data)

    def test_substitution_headers_two_origins_and_tls_use_real_upstream_configuration(self):
        identity = self.server.identity
        expected = f"localhost|{identity['http_ports'][0]}|{identity['http_ports'][1]}|{identity['https_ports'][0]}".encode()
        for scheme, host, port in [('http', 'localhost', identity['http_ports'][0]),
                                   ('http', 'www1.localhost', identity['http_ports'][1]),
                                   ('https', 'localhost', identity['https_ports'][0])]:
            with self.client.open(f'{scheme}://{host}:{port}/template.sub.js', timeout=10) as response:
                self.assertEqual(response.read(), expected)
                self.assertEqual(response.headers['X-Upstream'], 'real-handler')
        self.assertEqual(self.server.changed_inputs(), [])
        # Security-feature helpers expand these placeholders even for HTTP
        # tests. Advertising the unserved protocols must be explicit.
        ports = identity['unserved_protocols']
        with self.client.open(self.server.base_url + '/shared.sub.js', timeout=10) as response:
            self.assertEqual(response.read(), f"{ports['ws'][0]}|{ports['wss'][0]}".encode())

    def test_result_collection_and_harness_resources_coexist_with_upstream_routes(self):
        base = self.server.base_url
        with self.client.open(base + '/resources/testharnessreport.js', timeout=10) as response:
            self.assertEqual(response.read(), b'collector')
        with self.client.open(Request(base + '/__runner/alive', data=b'/case.html'), timeout=10) as response:
            self.assertEqual(response.status, 204)
        payload = {'harness': {'status': 0}, 'tests': []}
        with self.client.open(Request(base + '/__runner/result', data=json.dumps(payload).encode()), timeout=10) as response:
            self.assertEqual(json.load(response), {'next': '/next.html'})
        self.assertEqual(self.observer.payloads[-1], payload)
        self.assertEqual(self.observer.alive[-1], '/case.html')


if __name__ == '__main__':
    unittest.main()
