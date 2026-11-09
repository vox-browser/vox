import os
from pathlib import Path
import ssl
import tempfile
import unittest
from unittest.mock import patch
from urllib.request import HTTPSHandler, ProxyHandler, build_opener

from wpt_upstream_compare import (ManifestServer, checkout_identity, manifest_cases,
                                  origin_url, select_cases, verify_checkout)
from wpt_upstream_server_test import Observer


CHECKOUT = Path(os.environ.get('VOX_WPT_CHECKOUT', Path.home() / 'code/3rd/web-platform-tests'))


def manifest(entries):
    return dict(version=9, url_base='/', items={'testharness': entries})


class ManifestSelectionTests(unittest.TestCase):
    def test_generated_variants_queries_timeouts_and_protocols_remain_distinct(self):
        cases, counts = manifest_cases(manifest({'api': {
            'sample.any.js': ['blob', ['api/sample.any.html?one=%2F&two=2', {}],
                             ['api/sample.any.worker.html', {'timeout': 'long'}],
                             ['api/sample.any.serviceworker.html', {}]],
            'secure.https.html': ['blob', [None, {}]],
            'flags.html': ['blob', ['api/flags.html?wpt_flags=https&wpt_flags=www', {}]],
            'stream.h2.html': ['blob', [None, {}]],
        }}))
        self.assertEqual(len(cases), 6)
        self.assertEqual(counts['types']['testharness']['test_variants'], 6)
        by_id = {case['id']: case for case in cases}
        query = by_id['/api/sample.any.html?one=%2F&two=2']
        self.assertEqual(query['url'], '/api/sample.any.html?one=%2F&two=2')
        self.assertEqual(query['path'], 'api/sample.any.js')
        self.assertEqual(by_id['/api/sample.any.worker.html']['harness_timeout'], 60)
        self.assertEqual(by_id['/api/sample.any.serviceworker.html']['protocol'], 'https')
        self.assertEqual(by_id['/api/secure.https.html']['protocol'], 'https')
        flags = by_id['/api/flags.html?wpt_flags=https&wpt_flags=www']
        self.assertEqual((flags['protocol'], flags['subdomain']), ('https', 'www'))
        self.assertEqual(by_id['/api/stream.h2.html']['protocol'], 'h2')

    def test_other_types_are_counted_without_being_called_testharness_results(self):
        data = manifest({'one.html': ['blob', [None, {}]]})
        data['items']['manual'] = {'human.html': ['blob', [None, {}]]}
        cases, inventory = manifest_cases(data)
        self.assertEqual([c['id'] for c in cases], ['/one.html'])
        self.assertEqual(inventory['test_variants'], 2)

    def test_duplicate_or_invalid_variants_cannot_silently_reduce_the_denominator(self):
        for variants in [[['same.html', {}], ['same.html', {}]],
                         [['../escape.html', {}]], [['//remote.test/test.html', {}]],
                         [['test.html', {'timeout': 'unexpected'}]]]:
            with self.subTest(variants=variants), self.assertRaises(ValueError):
                manifest_cases(manifest({'source.any.js': ['blob', *variants]}))

    def test_selection_applies_explicit_prefix_offset_limit_after_complete_discovery(self):
        cases, _ = manifest_cases(manifest({'api': {
            'a.html': ['blob', [None, {}]], 'b.html': ['blob', [None, {}]]},
            'api-other.html': ['blob', [None, {}]]}))
        self.assertEqual([c['id'] for c in select_cases(cases, ['api'], 1, 1)], ['/api/b.html'])
        self.assertEqual(len(select_cases(cases, [], 0, None)), 3)

    def test_origin_uses_secure_port_and_subdomain_and_rejects_unserved_h2(self):
        server = type('Server', (), dict(identity=dict(host='localhost', http_ports=[80], https_ports=[443])))()
        case = dict(url='/one.html?x=%2F', protocol='https', subdomain='www')
        self.assertEqual(origin_url(case, server), 'https://www.localhost:443/one.html?x=%2F')
        with self.assertRaises(ValueError):
            origin_url(dict(case, protocol='h2'), server)

    def test_checkout_identity_validates_manifest_blob_hashes_and_tracked_changes(self):
        data = manifest({'one.html': ['abc123', [None, {}]]})
        def clean_git(root, *args):
            return {('rev-parse', 'HEAD'): b'revision\n',
                    ('status', '--porcelain', '--untracked-files=no'): b'',
                    ('ls-files', '--stage', '-z'): b'100644 abc123 0\tone.html\0'}[args]
        with patch('wpt_upstream_compare.git', side_effect=clean_git):
            identity = checkout_identity(Path('/fixture'), data)
            self.assertEqual(identity['tracked_files'], 1)
            verify_checkout(Path('/fixture'), identity)
            with self.assertRaises(ValueError):
                checkout_identity(Path('/fixture'), manifest({'one.html': ['stale', [None, {}]]}))
        with patch('wpt_upstream_compare.git', return_value=b'changed'):
            with self.assertRaises(ValueError):
                checkout_identity(Path('/fixture'), data)


@unittest.skipUnless((CHECKOUT / 'tools/localpaths.py').is_file(), 'requires upstream WPT tools')
class OfficialRouteTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix='vox-wpt-official-routes-')
        root = Path(cls.temporary.name) / 'fixtures'
        (root / 'resources').mkdir(parents=True)
        (root / 'resources/testharness.js').write_bytes(b'unchanged harness bytes')
        (root / 'example.any.js').write_text('// META: title=Exact upstream wrappers\n// META: timeout=long\ntest(()=>assert_true(true),"original");\n')
        (root / 'example.window.js').write_text('// META: title=Window wrapper\ntest(()=>{},"window");\n')
        cls.server = ManifestServer(CHECKOUT, root, Observer(),
                                    {'/resources/testharnessreport.js': (b'collector', 'text/javascript')},
                                    '/__runner/alive', '/__runner/result', Path(cls.temporary.name) / 'certs')
        context = ssl.create_default_context(cafile=cls.server.identity['ca_certificate'])
        cls.client = build_opener(ProxyHandler({}), HTTPSHandler(context=context))

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.temporary.cleanup()

    def read(self, relative):
        with self.client.open(self.server.base_url + relative, timeout=10) as response:
            self.assertEqual(response.status, 200)
            return response.read().decode()

    def test_window_and_worker_wrappers_come_from_the_upstream_handlers(self):
        html = self.read('/example.any.html?value=%2F')
        self.assertIn('<script src="/example.any.js"></script>', html)
        self.assertIn('content="long"', html)
        self.assertIn('Exact upstream wrappers', html)
        worker = self.read('/example.any.worker.html?value=%2F')
        self.assertIn('fetch_tests_from_worker(new Worker("/example.any.worker.js?value=%2F"))', worker)
        self.assertIn('importScripts("/example.any.js")', self.read('/example.any.worker.js'))
        self.assertIn('example.window.js', self.read('/example.window.html'))

    def test_original_harness_and_collector_are_served_separately(self):
        self.assertEqual(self.read('/resources/testharness.js'), 'unchanged harness bytes')
        self.assertEqual(self.read('/resources/testharnessreport.js'), 'collector')
        port = self.server.identity['https_ports'][0]
        with self.client.open(f'https://localhost:{port}/example.any.html', timeout=10) as response:
            self.assertIn(b'Exact upstream wrappers', response.read())
        self.assertEqual(self.server.changed_inputs(), [])


if __name__ == '__main__':
    unittest.main()
