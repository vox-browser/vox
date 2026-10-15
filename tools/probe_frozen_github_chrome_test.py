import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock

from probe_frozen_github_chrome import ReplayCDP, cache_response


class FrozenChromeProbeTests(unittest.TestCase):
    def test_cache_preserves_binary_bytes_and_exact_query_key(self):
        with tempfile.TemporaryDirectory() as directory:
            cache = Path(directory)
            (cache / 'resources').mkdir()
            url = 'https://assets.example/font.woff2?version=2'
            body = bytes(range(256))
            path = cache / 'resources' / hashlib.sha256(url.encode()).hexdigest()
            path.write_bytes(body)
            self.assertEqual(cache_response(cache, url, 'Font'), (body, 'font/woff2', path))
            self.assertIsNone(cache_response(cache, url.split('?')[0], 'Font'))
            self.assertIsNone(cache_response(cache, url, 'Document'))

    def client(self, cache, incoming):
        client = ReplayCDP.__new__(ReplayCDP)
        client.sequence = 0
        client.cache = cache
        client.responses = {}
        client.pending_replay = set()
        client.requests = []
        client.events = []
        client.send = Mock()
        client.receive = Mock(side_effect=incoming)
        return client

    def test_interleaved_fetch_ack_cannot_steal_command_response(self):
        client = self.client(Path('/missing-cache'), [
            {'method': 'Fetch.requestPaused', 'params': {'requestId': 'r', 'resourceType': 'Script',
             'request': {'url': 'https://example.test/a.js', 'method': 'GET'}}},
            {'id': 2, 'result': {}},
            {'method': 'Page.lifecycleEvent', 'params': {'name': 'firstPaint'}},
            {'id': 1, 'result': {'frameId': 'correct-frame'}},
        ])
        self.assertEqual(client.call('Page.navigate', {'url': 'https://example.test'}), {'frameId': 'correct-frame'})
        sent = [json.loads(c.args[0]) for c in client.send.call_args_list]
        self.assertEqual([c['id'] for c in sent], [1, 2])
        self.assertEqual(sent[1]['method'], 'Fetch.failRequest')
        self.assertFalse(client.pending_replay)
        self.assertEqual(client.events[0]['params']['name'], 'firstPaint')

    def test_missing_request_and_cached_non_get_never_fall_through(self):
        with tempfile.TemporaryDirectory() as directory:
            cache = Path(directory)
            (cache / 'resources').mkdir()
            url = 'https://example.test/a.js'
            (cache / 'resources' / hashlib.sha256(url.encode()).hexdigest()).write_bytes(b'response')
            client = self.client(cache, [
                {'method': 'Fetch.requestPaused', 'params': {'requestId': 'r', 'resourceType': 'Script',
                 'request': {'url': url, 'method': 'POST'}}},
                {'id': 2, 'result': {}}, {'id': 1, 'result': {}},
            ])
            client.call('Runtime.evaluate')
            methods = [json.loads(c.args[0])['method'] for c in client.send.call_args_list]
            self.assertEqual(methods, ['Runtime.evaluate', 'Fetch.failRequest'])


if __name__ == '__main__':
    unittest.main()
