#!/usr/bin/env python3
import base64
from html.parser import HTMLParser
import json
from pathlib import Path
import tempfile
import unittest

from page_archive import digest
from save_catalog_local import Exporter, save


class LocalCatalogTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.archive = Path(self.temp.name) / 'archive'
        (self.archive / 'bodies').mkdir(parents=True)
        self.url = 'https://boards.example/pol/catalog'
        self.manifest = dict(version=1, sealed_unix=1, captured_unix=1, url=self.url,
                             comparison_policy={'animated_images': 'frozen'}, responses={})
        self.add(self.url, 'text/html', '''<!DOCTYPE html><html><head>
<base href="https://cdn.example/pages/">
<link rel="stylesheet" id="base-css" media="screen" href="../css/catalog.css">
<link rel="preconnect" href="https://tracker.example">
<meta http-equiv="refresh" content="0;url=https://tracker.example">
</head><body onload="fetch('https://tracker.example')"><script src="/bad.js">fetch('/bad')</script>
<style>.inline {background:url('../images/flag.png')}</style>
<img src="../images/thumb.jpg" loading="lazy" onerror="fetch('/bad')"><iframe src="https://tracker.example"></iframe>
<a href="thread/123">a &amp; b</a>  preserved\n whitespace<a href="#bottom">Bottom</a></body></html>''')
        self.add('https://cdn.example/css/catalog.css', 'text/css', '''
@import "nested/font.css" screen;
.flag {background:url(../images/flag.png)}
/* url(https://inert.example/comment.png) */
.label::before {content:"url(https://inert.example/string.png)"}
''')
        self.add('https://cdn.example/css/nested/font.css', 'text/css',
                 '@font-face {src:url(../../font.woff2)}')
        self.add('https://cdn.example/font.woff2', 'font/woff2', b'font bytes')
        self.add('https://cdn.example/images/flag.png', 'image/png', b'flag bytes')
        self.add('https://cdn.example/images/thumb.jpg', 'image/jpeg', b'JPEG bytes unchanged')

    def add(self, url, content_type, body):
        if isinstance(body, str):
            body = body.encode()
        sha = digest(body)
        (self.archive / 'bodies' / sha).write_bytes(body)
        self.manifest['responses'][url] = dict(status=200, bytes=len(body), sha256=sha,
                                             headers=[dict(name='Content-Type', value=content_type)])
        (self.archive / 'manifest.json').write_text(json.dumps(self.manifest))

    def test_standalone_preserves_bytes_and_resolves_each_css_base(self):
        output = Path(self.temp.name) / 'catalog.html'
        receipt = save(self.archive, output)
        text = output.read_text()
        self.assertIn('<style id="base-css" media="screen">', text)
        self.assertIn('data:image/jpeg;base64,' + base64.b64encode(b'JPEG bytes unchanged').decode(), text)
        self.assertIn('data:image/png;base64,' + base64.b64encode(b'flag bytes').decode(), text)
        imported = text.split('@import "data:text/css;charset=utf-8;base64,')[1].split('"')[0]
        css = base64.b64decode(imported).decode()
        self.assertIn('data:font/woff2;base64,' + base64.b64encode(b'font bytes').decode(), css)
        self.assertIn('a &amp; b</a>  preserved\n whitespace', text)
        self.assertIn('href="https://cdn.example/pages/thread/123"', text)
        self.assertIn('href="#bottom"', text)
        self.assertEqual(receipt['sha256'], digest(output.read_bytes()))
        self.assertEqual(receipt['comparison_policy'], self.manifest['comparison_policy'])
        self.assertEqual(len(receipt['resources']), 6)
        # Asset references are fully embedded; passive hyperlink URLs are okay.
        class Resources(HTMLParser):
            def handle_starttag(self, tag, attrs):
                for k, v in attrs:
                    if k == 'src':
                        self_test.assertTrue(v.startswith(('data:', 'about:blank')), v)
        self_test = self
        Resources().feed(text)

    def test_active_network_sources_are_removed_and_csp_installed(self):
        text = Exporter(self.archive).render().decode()
        for value in ['<base', '<script', 'onload=', 'onerror=', 'preconnect', 'http-equiv="refresh"']:
            self.assertNotIn(value, text)
        self.assertIn('<iframe src="about:blank">', text)
        self.assertIn('Content-Security-Policy', text)
        self.assertIn('loading="eager"', text)
        self.assertIn("default-src &#x27;none&#x27;", text)
        self.assertIn('/* url(https://inert.example/comment.png) */', text)
        self.assertIn('content:"url(https://inert.example/string.png)"', text)

    def test_missing_resource_fails_before_output_is_written(self):
        del self.manifest['responses']['https://cdn.example/images/flag.png']
        (self.archive / 'manifest.json').write_text(json.dumps(self.manifest))
        output = Path(self.temp.name) / 'catalog.html'
        with self.assertRaisesRegex(ValueError, 'Missing archived resource'):
            save(self.archive, output)
        self.assertFalse(output.exists())

    def test_corrupt_archive_is_rejected(self):
        entry = self.manifest['responses'][self.url]
        (self.archive / 'bodies' / entry['sha256']).write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'Archived response changed'):
            Exporter(self.archive)

    def test_recursive_css_import_fails(self):
        self.add('https://cdn.example/css/nested/font.css', 'text/css', '@import url(../catalog.css);')
        with self.assertRaisesRegex(ValueError, 'Cyclic stylesheet import'):
            Exporter(self.archive).render()

    def test_unsupported_responsive_sources_fail(self):
        self.add(self.url, 'text/html', '<head></head><img srcset="a.jpg 1x, b.jpg 2x">')
        with self.assertRaisesRegex(ValueError, 'srcset is unsupported'):
            Exporter(self.archive).render()


if __name__ == '__main__':
    unittest.main()
