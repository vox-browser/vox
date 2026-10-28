import copy
from pathlib import Path
import unittest
from unittest.mock import patch

from check_catalog_local import OfflineCDP, TITLE, validate_brave_document


class LocalCatalogCaptureTest(unittest.TestCase):
    def test_rejects_incomplete_or_different_reference_documents(self):
        page = Path('/tmp/catalog.html')
        document = dict(url=page.as_uri(), title=TITLE, ready='complete', threads=201,
                        width=1024, height=768, scale=2,
                        thumbnails=[dict(complete=True, width=150) for _ in range(200)] +
                                   [dict(complete=True, width=0)])
        validate_brave_document(document, page, 1024, 768)
        for key, value in [('url', 'https://boards.4chan.org/pol/catalog'),
                           ('title', 'Navigation error'), ('ready', 'interactive'),
                           ('threads', 200), ('width', 800), ('height', 600), ('scale', 1)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate_brave_document(dict(document, **{key: value}), page, 1024, 768)
        for mutation in ['missing', 'undecoded', 'extra_broken']:
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                changed = copy.deepcopy(document)
                if mutation == 'missing':
                    changed['thumbnails'].pop()
                elif mutation == 'undecoded':
                    changed['thumbnails'][0]['complete'] = False
                else:
                    changed['thumbnails'][0]['width'] = 0
                validate_brave_document(changed, page, 1024, 768)

    def test_remote_request_attempts_are_retained_even_when_blocked(self):
        client = object.__new__(OfflineCDP)
        client.remote_requests = []
        for url in ['file:///tmp/catalog.html', 'data:image/png;base64,AA==',
                    'https://cdn.example/image.png', 'http://cdn.example/font.woff2']:
            event = dict(method='Network.requestWillBeSent', params=dict(request=dict(url=url)))
            with patch('check_catalog_local.CDP.receive', return_value=event):
                self.assertEqual(client.receive(), event)
        self.assertEqual(client.remote_requests, ['https://cdn.example/image.png',
                                                 'http://cdn.example/font.woff2'])


if __name__ == '__main__':
    unittest.main()
