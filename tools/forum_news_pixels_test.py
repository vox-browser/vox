import json
from pathlib import Path
import tempfile
import unittest

from forum_news_pixels import CATALOG, check_filters, check_native, seal_capture, write_json
from page_archive import digest, load_archive


class ForumNewsPixelTests(unittest.TestCase):
    def report(self):
        return dict(counts=dict(requests=1, blocked=0, allowed=1, mismatches=0, oracle_disagreements=0),
                    requests=[dict(actual=dict(blocked=False, exception=False),
                                   expected=dict(blocked=False, exception=False))],
                    navigation=dict(coverage='page', url='https://news.example/'),
                    common_stream=dict(matches=True),
                    cosmetic=dict(css_matches=True, procedural_matches=True, scriptlet_filters_match=True))

    def test_all_ten_sites_are_registered_once(self):
        sites = json.loads(CATALOG.read_text())['sites']
        self.assertEqual(len(sites), 10)
        self.assertEqual(len({s['url'] for s in sites}), 10)
        self.assertEqual(len({s['id'] for s in sites}), 10)
        self.assertEqual(sites[0]['id'], 'hacker-news')
        self.assertIn('reddit', {s['id'] for s in sites})
        for site in sites:
            directory = CATALOG.parent / 'sites' / site['id']
            self.assertTrue((directory / 'manifest.json').is_file() or (directory / 'status.json').is_file(), site['id'])

    def test_challenges_and_incomplete_filter_evidence_cannot_pass(self):
        check_filters(self.report())
        for coverage in ['challenge', 'error', 'consent', 'empty', 'unexpected-origin']:
            report = self.report()
            report['navigation']['coverage'] = coverage
            with self.assertRaises(RuntimeError):
                check_filters(report)
        for key in ['css_matches', 'procedural_matches', 'scriptlet_filters_match']:
            report = self.report()
            report['cosmetic'][key] = False
            with self.assertRaises(RuntimeError):
                check_filters(report)
        report = self.report()
        report['requests'][0]['actual']['error'] = 'engine failure'
        with self.assertRaises(RuntimeError):
            check_filters(report, document=False)
        for requests in [[], [dict(actual=dict(blocked=False, exception=False))]]:
            report = self.report()
            report['requests'] = requests
            with self.assertRaises(RuntimeError):
                check_filters(report)

    def test_native_error_page_wrong_document_and_wrong_viewport_are_rejected(self):
        reference = dict(url='https://news.example/', title='News')
        audit = dict(**reference, ready='complete', viewport_width=1024, viewport_height=768,
                     selections=[dict(name='body', elements=[dict(text='story ' * 300)])])
        check_native(audit, reference)
        for change in [dict(title='Access denied'), dict(url='about:blank'), dict(ready='loading'),
                       dict(viewport_width=800), dict(selections=[])]:
            with self.assertRaises(RuntimeError):
                check_native(dict(audit, **change), reference)

    def test_sealed_fixture_uses_only_captured_bytes_and_retains_filter_provenance(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            capture, archive = root / 'capture', root / 'archive'
            (capture / 'cache/resources').mkdir(parents=True)
            url = 'https://news.example/'
            html = b'<!doctype html><title>News</title><p>Frozen story</p>'
            (capture / 'frozen.html').write_bytes(html)
            (capture / 'live.png').write_bytes(b'captured PNG bytes')
            source = capture / 'cache/resources' / digest(url.encode())
            source.write_bytes(html)
            write_json(Path(str(source) + '.headers.json'), [dict(name='Content-Type', value='text/html;charset=windows-1251'),
                       dict(name='Content-Security-Policy', value="default-src 'self'")])
            write_json(capture / 'archive.json', dict(url=url, document_request_method='POST', frozen_html_sha256=digest(html), resources=[
                dict(url=url, sha256=digest(b'original scripted document')),
                dict(url=url + 'missing.png', error='body unavailable')]))
            report = root / 'report.json'
            write_json(report, self.report())
            seal_capture(capture, archive, report)
            manifest = load_archive(archive)
            self.assertEqual(manifest['source_document_request_method'], 'POST')
            self.assertEqual(set(manifest['responses']), {url})
            entry = manifest['responses'][url]
            self.assertEqual((archive / 'bodies' / entry['sha256']).read_bytes(), html)
            self.assertIn(dict(name='Content-Type', value='text/html;charset=utf-8'), entry['headers'])
            self.assertIn(dict(name='Content-Security-Policy', value="default-src 'self'"), entry['headers'])
            self.assertEqual(manifest['capture_report_sha256'], digest((archive / 'capture.json').read_bytes()))
            self.assertEqual(manifest['live_png_sha256'], digest((archive / 'live.png').read_bytes()))
            with self.assertRaises(FileExistsError):
                seal_capture(capture, archive, report)
            (archive / 'bodies' / entry['sha256']).write_bytes(b'changed')
            with self.assertRaises(ValueError):
                load_archive(archive)


if __name__ == '__main__':
    unittest.main()
